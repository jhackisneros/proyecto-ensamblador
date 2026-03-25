# Proyecto Ensamblador

## Descripción General

Entorno completo de desarrollo para programación en lenguaje ensamblador x86/x64. Incluye herramientas de análisis, depuración y documentación técnica para aprender arquitectura de computadoras y programación de bajo nivel.

## Objetivos

- Implementar un ensamblador funcional con soporte x86/x64
- Herramientas de depuración y análisis de código
- Documentación de arquitectura y modelos de ejecución
- Facilitar comprensión de la interacción hardware-software

## Características

- **Análisis Lexical y Sintáctico**: Parsing completo de código ensamblador
- **Generador de Código Máquina**: Traducción a bytecode ejecutable
- **Sistema de Símbolos**: Resolución de etiquetas y referencias
- **Gestión de Memoria**: Segmentos `.data`, `.text`, `.bss`
- **Directivas de Ensamblador**: Soporte completo

## Estructura

```
src/
├── main.asm
└── games/
    ├── invaders.asm
    ├── pong.asm
    └── tres.asm
```

## Requisitos

- Procesador x86/x64
- Entorno C++ o ensamblador cruzado

## Instalación y Uso

[Añade instrucciones de compilación y ejecución]

## Licencia

[Especifica tu licencia]
## Documentación Técnica

### Arquitectura x86/x64
- Registros y banderas de estado
- Modos de direccionamiento
- Conjunto de instrucciones (ISA)
- Convenciones de llamada (calling conventions)

### Guía de Instrucciones
- Instrucciones aritméticas y lógicas
- Control de flujo y saltos
- Operaciones con memoria
- Manejo de interrupciones

## Ejemplos de Código

### Hello World
```asm
section .data
    msg db "Hello, World!", 0

section .text
    global _start
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 13
    syscall
```

### Bucles y Condicionales
```asm
mov rcx, 10
loop_start:
    ; código del bucle
    dec rcx
    jnz loop_start
```

## Herramientas Recomendadas

- **NASM**: Ensamblador Netwide
- **GDB**: Depurador GNU
- **Radare2**: Framework de análisis
- **Objdump**: Análisis de binarios

## Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el repositorio
2. Crea una rama para tu feature
3. Envía un pull request con descripción clara

## Contacto y Soporte

Para reportar bugs o sugerencias, abre un issue en el repositorio.

## Referencias

- Intel 64 and IA-32 Architectures Software Developer's Manual
- MIT OpenCourseWare - Computation Structures
# Documentación de Referencia Técnica

## Descripción
Referencia a la especificación del Sistema V ABI para arquitectura x86-64, un estándar fundamental para la compilación y vinculación de código en sistemas Unix/Linux de 64 bits.

## Componentes Utilizados

### Especificación System V ABI x86-64
- **Propósito**: Define las convenciones de llamada, layout de memoria y formato de objetos binarios
- **Aplicación**: Asegura compatibilidad entre código ensamblador y compiladores
- **Relevancia**: Crítico para implementación correcta de funciones en x86-64

## Estructura del Proyecto
- **Ruta**: `/C:/Users/zairo/Documents/GitHub/proyecto-ensamblador/`
- **Archivo**: README.md
- **Contexto**: Documentación de proyecto de programación en ensamblador

## Estándares Implementados
- Convenciones de registros (rax, rbx, rcx, etc.)
- Alineación de stack (16 bytes)
- Paso de argumentos en llamadas a funciones
- Preservación de registros según ABI

## Notas Técnicas
Este documento se refiere a documentación normativa técnica que establece los requisitos obligatorios para código x86-64 compatible con sistemas Unix/Linux.
- x86-64 System V ABI Specification