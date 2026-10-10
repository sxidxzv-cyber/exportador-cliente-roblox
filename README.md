# Exportador de scripts del cliente — v2

Muestra el progreso, permite cancelar y guarda los resultados del descompilador del executor en archivos individuales.

## Ejecutarlo en Delta

1. Entra en una experiencia de Roblox y abre el editor de Delta.
2. Borra el contenido anterior, pega este comando y pulsa **EXECUTE**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sxidxzv-cyber/exportador-cliente-roblox/main/ExportadorCliente.lua"))()
```

3. Oculta el panel de Delta para ver la ventana del exportador, situada abajo.

Si aparece **Faltan funciones del executor**, la ventana indica cuál falta. Se necesitan `decompile`, `writefile` y `makefolder`; este archivo usa las funciones que proporciona tu versión del executor.

## Resultados

Se crea una carpeta `ClienteScripts_<PlaceId>_<identificador>` en el almacenamiento de archivos del executor. Su ubicación exacta depende del executor.

- Un archivo `.lua` por cada resultado guardado.
- `reporte.json` con rutas originales, recuentos y errores.
- Los nombres llevan un número para evitar que scripts con el mismo nombre se sobrescriban.

## Alcance

Revisa los scripts visibles en el cliente al iniciar: `LocalScript`, `ModuleScript` y `Script` con `RunContext.Client`, dentro de las ubicaciones que recorre el archivo.

La calidad del código recuperado depende de la función nativa `decompile`. Este exportador añade diagnósticos y organiza los resultados; no implementa un descompilador nuevo.

No recupera scripts exclusivos del servidor ni exporta mapas, modelos, interfaces o archivos `.rbxl`. No ejecuta el código recuperado.

La cancelación y el límite de 15 segundos por script requieren que el descompilador permita ceder el hilo; una llamada nativa que bloquee el proceso puede impedir ambas cosas.

## Verificación

Sintaxis y comportamiento revisados con simulaciones de exportación, funciones faltantes, fallos de escritura, cancelación y tiempo límite. No se ha probado en una instalación real de Delta.
