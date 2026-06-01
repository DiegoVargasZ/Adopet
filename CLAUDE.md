# AdoptaPet — Claude Code Instructions

## Descripción del proyecto
Aplicación web y móvil para adopción responsable de animales en Bolivia (Cochabamba).
Conecta adoptantes con refugios verificados mediante mapa interactivo, chat en tiempo real,
donaciones y rastreador GPS de mascotas.

---

## Stack tecnológico

### Frontend
- **Framework**: Flutter (Web + Android + iOS)
- **Lenguaje**: Dart SDK ^3.9.0
- **State management**: flutter_riverpod ^2.6.1
- **Navegación**: go_router ^16.0.0
- **Mapas**: flutter_map ^6.1.0 + latlong2 ^0.9.0
- **GPS**: geolocator ^11.0.0
- **HTTP**: http ^1.2.0
- **Imágenes**: image_picker ^1.1.2
- **Utilidades**: intl ^0.20.2, uuid ^4.5.1, url_launcher ^6.2.5

### Backend
- **Plataforma**: Supabase
- **URL**: https://lpxnokopyksxlbdeljmg.supabase.co
- **Base de datos**: PostgreSQL con RLS (Row Level Security)
- **Auth**: Supabase Auth (email/password, AuthFlowType.implicit para web)
- **Realtime**: Supabase Realtime (chat y tracker GPS)
- **Storage**: Supabase Storage (bucket: pet-images)
- **RPC**: funciones PostgreSQL con security definer

### APIs externas
- **Mapas tiles**: OpenStreetMap (gratuito, sin API key)
- **Rutas**: OpenRouteService API (gratuito, requiere API key en map_screen.dart)

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart       # URL y anonKey de Supabase
│   ├── theme/
│   │   └── app_theme.dart             # Tema Material3, colores primary/secondary
│   ├── router/
│   │   └── app_router.dart            # GoRouter con _AuthNotifier y redirects
│   └── providers/
│       ├── role_provider.dart         # AsyncNotifierProvider<UserProfile?>
│       └── pet_filter_provider.dart   # NotifierProvider<PetFilter>
├── data/
│   ├── models/
│   │   ├── user_profile.dart          # id, full_name, role, helpers isAdmin/isShelter
│   │   ├── shelter.dart               # id, name, lat, lng, user_id
│   │   ├── pet.dart                   # id, shelter_id, species, gender, age_months
│   │   ├── pet_filter.dart            # species, gender, ageRange + ageMonthsRange
│   │   ├── message.dart               # id, chat_id, sender_id, content
│   │   ├── chat_preview.dart          # shelter, lastMessage, unreadCount
│   │   ├── donation.dart              # amount, currency(BOB), status
│   │   ├── tracker.dart               # id, user_id, pet_id, is_active
│   │   └── tracker_location.dart      # lat, lng, accuracy, recorded_at
│   └── services/
│       ├── shelter_service.dart       # getShelters()
│       ├── pet_service.dart           # getPets(filter,search), CRUD mascotas
│       ├── chat_service.dart          # getOrCreateChat(), realtime subscribeToMessages()
│       ├── donation_service.dart      # donate(), getMyDonations(), getShelterTotals()
│       ├── tracker_service.dart       # startAutoTracking(30s), subscribeToLocations()
│       └── role_service.dart          # getMyProfile(), requestShelterRole(), admin ops
└── presentation/
    ├── screens/
    │   ├── splash/                    # SplashScreen (estático, sin context.go)
    │   ├── auth/                      # LoginScreen (login + registro en una pantalla)
    │   ├── home/                      # HomeScreen (menú adaptado por rol)
    │   ├── map/                       # MapScreen (flutter_map + ORS routes)
    │   ├── pets/                      # PetsScreen (grid + filtros), PetDetailScreen
    │   ├── shelters/                  # SheltersScreen, ShelterCard
    │   ├── chat/                      # ChatsListScreen, ChatScreen (realtime)
    │   ├── donations/                 # DonationScreen, MyDonationsScreen
    │   ├── trackers/                  # TrackersScreen, TrackerMapScreen
    │   └── roles/
    │       ├── request_shelter_screen.dart
    │       ├── admin_panel_screen.dart    # 3 tabs: stats, solicitudes, usuarios
    │       ├── manage_pets_screen.dart    # CRUD mascotas del refugio
    │       └── shelter_donations_screen.dart
    └── widgets/
        ├── pet_card.dart              # Card con imagen, tags de edad/género
        └── shelter_card.dart          # Card con botones mapa y donar
```

---

## Rutas (go_router)

| Ruta | Pantalla | Notas |
|------|----------|-------|
| `/` | SplashScreen | Redirect automático según sesión |
| `/login` | LoginScreen | Login + registro en una sola pantalla |
| `/home` | HomeScreen | Menú dinámico según rol |
| `/map` | MapScreen | Requiere API key ORS |
| `/pets` | PetsScreen | Filtros en panel lateral |
| `/pets/detail` | PetDetailScreen | extra: Pet |
| `/shelters` | SheltersScreen | |
| `/chats` | ChatsListScreen | |
| `/chats/chat` | ChatScreen | extra: Map{chatId, shelterName} |
| `/donations` | DonationScreen | extra: Shelter |
| `/my-donations` | MyDonationsScreen | |
| `/trackers` | TrackersScreen | |
| `/trackers/map` | TrackerMapScreen | extra: Tracker |
| `/request-shelter` | RequestShelterScreen | Solo rol adoptante |
| `/admin` | AdminPanelScreen | Solo rol admin |
| `/manage-pets` | ManagePetsScreen | Solo rol refugio/admin |
| `/shelter-donations` | ShelterDonationsScreen | Solo rol refugio/admin |

---

## Base de datos — tablas Supabase

| Tabla | Columnas clave | RLS |
|-------|---------------|-----|
| profiles | id, full_name, email, role, avatar_url | Sí |
| shelters | id, user_id, name, lat, lng, address | Sí |
| pets | id, shelter_id, name, species, gender, age_months, is_adopted | Sí |
| chats | id, user_id, shelter_id | Sí |
| messages | id, chat_id, sender_id, content, is_read | Sí |
| donations | id, user_id, shelter_id, amount, currency, status | Sí |
| trackers | id, user_id, pet_id, name, is_active | Sí |
| tracker_locations | id, tracker_id, lat, lng, accuracy, recorded_at | Sí |
| shelter_requests | id, user_id, shelter_name, status, admin_note | Sí |

### Funciones RPC importantes
- `handle_new_user()` — trigger: crea perfil con role='adoptante' al registrarse
- `approve_shelter_request(request_id)` — aprueba solicitud + cambia role + crea shelter
- `reject_shelter_request(request_id, note)` — rechaza con nota

---

## Sistema de roles

```
adoptante (default)
    ↓ solicita mediante RequestShelterScreen
    ↓ admin aprueba en AdminPanelScreen
refugio
    → puede gestionar mascotas, ver donaciones, responder chats

admin (asignado por SQL directo)
    → todo lo anterior + aprobar solicitudes + cambiar roles + estadísticas
```

### SQL para crear admin
```sql
insert into profiles (id, full_name, role, email)
select id, 'Administrador', 'admin', email
from auth.users
where email = 'EMAIL_AQUI'
on conflict (id) do update set role = 'admin';
```

---

## Patrones de código obligatorios

### Riverpod — siempre usar ConsumerWidget o ConsumerStatefulWidget
```dart
// CORRECTO
class MyScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(roleProvider);
  }
}

// INCORRECTO — nunca usar provider package
class MyScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    final role = context.watch<RoleProvider>(); // ❌
  }
}
```

### Navegación — siempre usar go_router
```dart
// CORRECTO
context.push('/pets');
context.go('/home');
context.push('/pets/detail', extra: pet);

// INCORRECTO
Navigator.pushNamed(context, '/pets'); // ❌
Navigator.push(context, MaterialPageRoute(...)); // ❌
```

### Providers — patrón AsyncNotifier
```dart
final myProvider = AsyncNotifierProvider<MyNotifier, MyModel?>(MyNotifier.new);

class MyNotifier extends AsyncNotifier<MyModel?> {
  @override
  Future<MyModel?> build() async => await MyService().getData();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => MyService().getData());
  }
}
```

### Servicios — siempre usar Supabase.instance.client
```dart
class MyService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<MyModel>> getItems() async {
    final data = await _client.from('table').select().order('created_at');
    return (data as List).map((e) => MyModel.fromJson(e)).toList();
  }
}
```

---

## Restricciones importantes

### NO hacer
- ❌ Usar `provider` package (el proyecto usa `flutter_riverpod`)
- ❌ Usar `Navigator.push` o `Navigator.pushNamed` (usar `context.push/go`)
- ❌ Llamar `context.go()` desde `SplashScreen` (el router maneja el redirect)
- ❌ Hardcodear el UUID de usuarios en el código
- ❌ Exponer la `anonKey` en repositorios públicos
- ❌ Deshabilitar RLS en producción
- ❌ Usar `StatefulWidget` cuando se necesita estado de Riverpod (usar `ConsumerStatefulWidget`)
- ❌ Importar `package:provider/provider.dart`
- ❌ Agregar rutas sin registrarlas en `app_router.dart`

### SÍ hacer
- ✅ Todos los widgets que usan providers deben extender `ConsumerWidget` o `ConsumerStatefulWidget`
- ✅ Manejar el estado de carga con `AsyncValue.when(loading, error, data)`
- ✅ Usar `mounted` antes de llamar `setState` después de operaciones async
- ✅ Siempre hacer `dispose()` de `TextEditingController` y `RealtimeChannel`
- ✅ Usar `context.mounted` antes de navegar después de operaciones async
- ✅ Traducir errores de Supabase Auth al español en la UI
- ✅ Usar `ConstrainedBox(maxWidth: 480)` en formularios para compatibilidad web
- ✅ Registrar nuevas rutas en `app_router.dart` con sus imports correspondientes

---

## Configuración de autenticación web

```dart
// main.dart — obligatorio para Flutter Web
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.implicit, // requerido para web
  ),
);
```

---

## Permisos Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

## Permisos iOS (Info.plist)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para mostrarte refugios cercanos</string>
```

---

## Colores del tema

```dart
static const primary   = Color(0xFFFF6B35); // Naranja principal
static const secondary = Color(0xFF2D6A4F); // Verde naturaleza
// Admin:   Color(0xFF1A237E) — Azul oscuro
// Refugio: Color(0xFFFF6B35) — Naranja
// Adoptante: Color(0xFF2D6A4F) — Verde
```

---

## Errores conocidos y soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `No GoRouter found in context` | SplashScreen llamando context.go() antes de que el árbol esté listo | SplashScreen debe ser StatelessWidget sin navegación |
| `RLS policy violation on profiles` | Insert bloqueado por políticas | Agregar policy `with check(true)` para insert |
| `column pets.is_adopted does not exist` | Columna con nombre diferente | `ALTER TABLE pets ADD COLUMN is_adopted boolean` |
| Splash screen congelada | GoRouter no detecta cambio de sesión | Usar `_AuthNotifier extends ChangeNotifier` con stream |
| Login sin campos en web | `SingleChildScrollView` sin altura | Envolver en `Center + ConstrainedBox(maxWidth: 480)` |
| `null value in column id` | Email no encontrado en auth.users | Usar SELECT en vez de VALUES en el INSERT |

---

## Comandos útiles

```bash
# Instalar dependencias
flutter pub get

# Limpiar caché (cuando hay errores extraños)
flutter clean && flutter pub get

# Correr en web
flutter run -d chrome

# Correr en Android
flutter run -d android

# Build web para producción
flutter build web --release
```

---

## Assets requeridos

```
assets/
├── images/   # Imágenes locales de la app
└── icons/    # Íconos personalizados
```

Declarados en `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
```
