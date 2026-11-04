"""Instala plugins de Jenkins directamente en JENKINS_HOME, sin pasar por la UI.

Pensado para reparar una instalacion de plugins que quedo a medias (el asistente
de Jenkins deja archivos `*.jpi.tmp` de 0 bytes cuando la descarga falla, y los
plugins que dependian de ellos no cargan).

Lee el catalogo cacheado en `updates/default.json`, calcula el cierre de
dependencias no opcionales de los plugins objetivo, y descarga solo los `.jpi`
que falten o que no alcancen la version minima exigida. Verifica el sha256 de
cada descarga, para no repetir el fallo de los archivos truncados.

Uso:
    python install-plugins-offline.py               # informa, no descarga
    python install-plugins-offline.py --apply       # instala

Despues de instalar hay que reiniciar Jenkins para que los plugins se activen.
Si algun archivo pertenece a SYSTEM (porque lo escribio el servicio), la
escritura falla con "Access is denied": en ese caso ejecuta el script desde una
consola como administrador.
"""
import base64
import hashlib
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

JENKINS_HOME = os.environ.get('JENKINS_HOME', r'C:\ProgramData\Jenkins\.jenkins')
PLUGINS_DIR = os.path.join(JENKINS_HOME, 'plugins')
CATALOG = os.path.join(JENKINS_HOME, 'updates', 'default.json')

# Plugins que necesita el pipeline de Adopet.
TARGETS = [
    'pipeline-stage-step',   # dependencia de Pipeline: Declarative
    'workflow-aggregator',   # suite completa de Pipeline
    'git',                   # checkout del repositorio
    'pipeline-graph-view',   # vista grafica de etapas
]

APPLY = '--apply' in sys.argv


def version_key(value):
    """Orden aproximado de versiones de Jenkins ('1336.vee415d95c521' -> 1336)."""
    out = []
    for token in re.split(r'[._\-+]', value or ''):
        out.append((1, int(token)) if token.isdigit() else (0, token))
    return out


def _version_from_lines(lines):
    for line in lines:
        if line.startswith('Plugin-Version:'):
            return line.split(':', 1)[1].strip()
    return None


def read_installed():
    """Version de cada plugin presente en JENKINS_HOME/plugins.

    Mira tanto los directorios ya explotados (plugins/<nombre>/META-INF) como
    los archivos `.jpi` sueltos, porque un plugin recien copiado todavia no
    esta explotado: Jenkins lo hace al arrancar. Asi el script es idempotente
    y no vuelve a descargar lo que ya dejo instalado.
    """
    installed = {}

    for entry in os.listdir(PLUGINS_DIR):
        if not entry.endswith('.jpi'):
            continue
        try:
            with zipfile.ZipFile(os.path.join(PLUGINS_DIR, entry)) as archive:
                text = archive.read('META-INF/MANIFEST.MF').decode('utf-8', 'replace')
            version = _version_from_lines(text.splitlines())
            if version:
                installed[entry[:-len('.jpi')]] = version
        except (zipfile.BadZipFile, KeyError, OSError):
            continue

    # Nos quedamos con la version mas alta entre el .jpi y el directorio
    # explotado: el .jpi es lo que Jenkins cargara tras el reinicio.
    for name in os.listdir(PLUGINS_DIR):
        manifest = os.path.join(PLUGINS_DIR, name, 'META-INF', 'MANIFEST.MF')
        if os.path.isdir(os.path.join(PLUGINS_DIR, name)) and os.path.exists(manifest):
            version = _version_from_lines(io.open(manifest, encoding='utf-8', errors='replace'))
            if not version:
                continue
            known = installed.get(name)
            if known is None or version_key(version) > version_key(known):
                installed[name] = version

    return installed


def load_catalog():
    raw = io.open(CATALOG, encoding='utf-8').read().strip()
    if raw.startswith('updateCenter.post('):
        raw = raw[len('updateCenter.post('):].rstrip(');')
    return json.loads(raw)['plugins']


def resolve(catalog):
    """Cierre de dependencias -> {nombre: version minima exigida}."""
    required = {}
    unknown = []

    def visit(name, demanded):
        entry = catalog.get(name)
        if entry is None:
            unknown.append(name)
            return
        if name in required and version_key(required[name]) >= version_key(demanded):
            return
        required[name] = demanded
        for dep in entry['dependencies']:
            if not dep.get('optional'):
                visit(dep['name'], dep['version'])

    for target in TARGETS:
        entry = catalog.get(target)
        # Para los objetivos pedimos la version del catalogo; para las
        # dependencias, solo el minimo que declara quien las necesita.
        visit(target, entry['version'] if entry else '0')

    return required, unknown


def main():
    if not os.path.exists(CATALOG):
        print('No existe %s.' % CATALOG)
        print('Abre Jenkins -> Manage Plugins para que descargue el catalogo y reintenta.')
        return 1

    catalog = load_catalog()
    installed = read_installed()
    required, unknown = resolve(catalog)

    pending = []
    for name in sorted(required):
        current = installed.get(name)
        if current is None:
            pending.append((name, catalog[name]['version'], 'FALTA'))
        elif version_key(current) < version_key(required[name]):
            pending.append((name, catalog[name]['version'],
                            'actualizar desde %s (se exige %s)' % (current, required[name])))

    print('objetivos: %s' % ', '.join(TARGETS))
    print('cierre de dependencias: %d plugins' % len(required))
    if unknown:
        print('SIN METADATOS EN EL CATALOGO: %s' % ', '.join(unknown))
    print()

    if not pending:
        print('Nada que hacer: todos los plugins necesarios estan instalados.')
        return 0

    print('a instalar: %d' % len(pending))
    for name, version, why in pending:
        print('  %-28s %-34s %s' % (name, version, why))

    if not APPLY:
        print()
        print('(dry-run: nada se descargo; usa --apply para instalar)')
        return 0

    print()
    errors = []
    for name, version, _why in pending:
        entry = catalog[name]
        destination = os.path.join(PLUGINS_DIR, name + '.jpi')
        staging = destination + '.download'
        print('descargando %s %s ...' % (name, version), end=' ')
        try:
            request = urllib.request.Request(
                entry['url'], headers={'User-Agent': 'adopet-offline-plugin-installer'})
            with urllib.request.urlopen(request, timeout=180) as response:
                data = response.read()

            expected = entry.get('sha256')
            actual = base64.b64encode(hashlib.sha256(data).digest()).decode()
            if expected and actual != expected:
                raise ValueError('sha256 no coincide (esperado %s, obtenido %s)' % (expected, actual))

            with io.open(staging, 'wb') as handle:
                handle.write(data)
            if os.path.exists(destination):
                os.remove(destination)
            os.rename(staging, destination)
            print('OK (%d KB, sha256 verificado)' % (len(data) // 1024))
        except Exception as exc:
            print('FALLO: %s' % exc)
            errors.append((name, str(exc)))
            if os.path.exists(staging):
                os.remove(staging)

    # Limpia los .jpi.tmp vacios que deja una instalacion fallida.
    cleaned, blocked = [], []
    for entry in os.listdir(PLUGINS_DIR):
        if entry.endswith('.jpi.tmp'):
            path = os.path.join(PLUGINS_DIR, entry)
            try:
                if os.path.getsize(path) == 0:
                    os.remove(path)
                    cleaned.append(entry)
            except OSError:
                blocked.append(entry)
    if cleaned:
        print()
        print('eliminados %d archivos .jpi.tmp vacios' % len(cleaned))
    if blocked:
        print('no se pudieron borrar (pertenecen a SYSTEM, usa una consola de administrador): %d'
              % len(blocked))

    if errors:
        print()
        print('ERRORES:')
        for name, message in errors:
            print('  %s: %s' % (name, message))
        return 1

    print()
    print('Listo. Reinicia Jenkins para activar los plugins:')
    print('  Restart-Service jenkins      (consola de administrador)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
