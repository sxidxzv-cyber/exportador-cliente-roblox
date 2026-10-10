# Exportador de lugar y scripts — Said v3.1

Guarda el contenido visible en el cliente como lugar de Roblox, conserva su jerarquía y crea una copia de los scripts en carpetas. El nombre del lugar termina en **_said.rbxl**. La descompilación usa la función que proporciona el executor; no implementa un descompilador nuevo.

## Ejecutarlo en Delta

1. Entra en Roblox y espera a que cargue el mapa.
2. Abre el editor de Delta y ejecuta:

~~~lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sxidxzv-cyber/exportador-cliente-roblox/main/ExportadorCliente.lua", true))()
~~~

3. Oculta el panel de Delta para ver **Exportador de lugar · Said v3.1**.
4. Espera a que termine la copia de scripts y después el guardado del lugar. La ventana muestra la carpeta y el archivo final.

Se necesitan **writefile**, **makefolder**, acceso HTTP y **loadstring**. Si falta **decompile**, intenta guardar el mapa y las interfaces sin recuperar el código de scripts. Si falta **setfenv**, el serializador usa el descompilador nativo, sin reutilizar la captura inicial.

## Archivos que crea

En el almacenamiento de archivos del executor, dentro de una carpeta como **Exportacion_123456_ab12cd34_said**:

- **Lugar_123456_20261010_200000_ab12cd34_said.rbxl**: lugar binario con mapa, modelos, servicios e interfaces presentes en el cliente.
- **scripts/**: archivos Lua organizados por servicio y carpetas originales. Los índices evitan sobrescribir scripts con nombres repetidos.
- **reporte.json**: rutas originales, scripts guardados, fallos, límites, formato final y comprobaciones de escritura.

La ubicación física de esa carpeta depende de Delta y del sistema operativo. Este script no puede crear el archivo directamente en el chat ni confirmar dónde lo muestra el administrador de archivos de tu instalación.

El lugar conserva la jerarquía de instancias. El contenido del jugador local se conserva como una instantánea en la carpeta **LocalPlayer** del lugar; puede requerir colocarlo en los servicios correspondientes para usarlo en otro proyecto. Los avatares de jugadores se omiten. Las carpetas del respaldo Lua se acortan cuando son demasiado profundas; las rutas completas permanecen en el reporte.

## Formato y errores

**decompilation panicked** significa que el descompilador devolvió un fallo y no recuperó el código de ese script. La revisión 3.1 reconoce ese diagnóstico y otros mensajes de error conocidos cuando no contienen código, los cuenta como **fallos** y conserva el mensaje en el reporte y en el comentario del script del lugar. No los guarda como archivos Lua recuperados. Un texto igual dentro de una cadena o de un comentario de un script con código se conserva.

Esta corrección evita contar mensajes de error como descompilaciones exitosas. No corrige el descompilador nativo de Delta ni reconstruye automáticamente los módulos afectados.

Se intenta primero un **.rbxl binario**, sin compresión. Antes de escribir se comprueba su cabecera, los límites de sus bloques y el bloque final. Si hay **readfile**, también se compara lo escrito con todos los datos originales. Esto no sustituye abrir y revisar el lugar en Roblox Studio.

Si falla el binario, se intenta un lugar XML con nombre terminado en **_said.rbxlx**. Ese archivo también se abre en Roblox Studio y se puede convertir a **.rbxl** con **Guardar como**. Nunca se cambia la extensión de un XML para presentarlo como binario. Si ambos intentos fallan, los scripts que ya se guardaron se conservan.

La cancelación conserva los archivos completados. Durante la serialización espera a que la llamada en curso termine y descarta el resultado pendiente. El límite de 15 segundos del descompilador requiere que la función nativa permita ceder el hilo. Después de un bloqueo no inicia más llamadas de descompilación desde la captura inicial.

## Lo que se puede recuperar

Solo contenido que ya está disponible en el cliente. El código exclusivo de **ServerScriptService** y **ServerStorage** nunca llega al cliente y no se puede extraer con este script. Los objetos replicados usados por el servidor pueden aparecer, pero eso no recupera su lógica privada.

Con **StreamingEnabled** pueden faltar zonas que todavía no se hayan cargado. Mallas, imágenes, sonidos y otros recursos externos se guardan como referencias; sus permisos siguen aplicando. El resultado no garantiza un juego completo o funcional. No se ejecuta el código recuperado ni se envía a un servicio de descompilación.

## Dependencias y crédito

Serialización de lugares: **UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw**, de [luau/UniversalSynSaveInstance](https://github.com/luau/UniversalSynSaveInstance), bajo GNU AGPL v3. La licencia completa está en **USSI_LICENSE.txt**. El envoltorio y sus modificaciones se distribuyen con esa misma licencia.

Revisiones utilizadas:

- USSI: **089986506e7ab9c50d7065d48b36e3bfbd5f78d7**.
- StreamBuffer y UniversalMethodFinder de luau/SomeHub: **beabe12be11b007777cfef0bffbe68dfb3f8b3b9**.
- Base64 de daily3014/rbx-algorithms: **468dde82bdba89176157dcec90ba503b7046f5b3**.
- llz4 de RiskoZS: **57d869215b7a061121f5492ecff245989638816a**.

El 10 de octubre de 2026 se añadió este envoltorio con interfaz, organización, reporte, caché de scripts y validación del archivo. Al cargar USSI se sustituyen sus cuatro rutas de código auxiliar por las revisiones anteriores y su ruta de recursos LinkedSource por el dominio oficial assetdelivery.roblox.com. USSI descarga además metadatos de Roblox para conocer las propiedades de cada clase.

La revisión 3.1, del mismo día, añade la detección de diagnósticos devueltos como texto sin código.

## Verificación

El envoltorio pasó 39 simulaciones de capacidades, cancelación, tiempos límite, archivos truncados, formatos incorrectos, fallos de escritura, alternativas de guardado y diagnósticos de descompilación. Incluyen el mensaje reportado, variantes con comentarios y código válido que contiene esa frase. No se ha probado esta revisión en una instalación real de Delta ni se ha abierto su resultado en Roblox Studio.

