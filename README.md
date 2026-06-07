# Proyecto de Base de Datos para un E-commerce

## Descripción

Este proyecto tiene como objetivo diseñar e implementar el núcleo de una base de datos relacional para una tienda en línea. El sistema gestiona de forma eficiente y segura toda la información relacionada con productos, inventario, clientes y el ciclo de vida de las ventas. La estructura está construida sobre MySQL e incluye consultas avanzadas de análisis, funciones reutilizables, un esquema de seguridad por roles, triggers de automatización, eventos programados y procedimientos almacenados transaccionales, garantizando integridad, escalabilidad y trazabilidad de los datos en todo momento.

---

## Integrantes

- Tomas Esteban Gonzalez Quintero

---

## Instrucciones de Ejecución

Ejecutar los archivos en el siguiente orden desde cualquier cliente MySQL (DBeaver, MySQL Workbench, etc.):

### 1. `01_Esquema_y_Datos.sql`
Crea la base de datos `ecommerce_db`, define todas las tablas con sus relaciones y restricciones, e inserta los datos de ejemplo aleatorios en categorías, proveedores, productos, clientes, ventas y detalles de ventas.

### 2. `02_Consultas_Avanzadas.sql`
Contiene 20 consultas de análisis y reporteo de negocio: top de productos más vendidos, clientes VIP, análisis mensual de ventas, segmentación RFM, predicción de demanda, entre otras.

### 3. `03_Funciones.sql`
Define 20 funciones reutilizables que encapsulan lógica de negocio: cálculo de totales, validación de email, estado de lealtad, conversión de moneda, estimación de fecha de entrega, entre otras.

### 4. `04_Seguridad.sql`
Implementa el esquema de seguridad: creación de roles, usuarios, asignación de permisos granulares, vistas de protección de datos sensibles y política de contraseñas seguras.

### 5. `05_Triggers.sql`
Crea las tablas de auditoría necesarias, agrega columnas extra al esquema base y define 20 triggers que automatizan procesos como control de stock, auditoría de precios, capitalización de nombres y archivado de ventas eliminadas.

### 6. `06_Eventos.sql`
Activa el event scheduler y define 20 eventos programados para tareas automáticas: reportes semanales, limpieza de datos, detección de fraude, cálculo de KPIs mensuales y purga de registros inactivos.

### 7. `07_Procedimientos_Almacenados.sql`
Define 20 procedimientos almacenados para operaciones complejas y transaccionales: procesamiento de ventas, devoluciones, fusión de cuentas, búsqueda avanzada de productos y generación de dashboards administrativos.

---

## Notas

- Los archivos deben ejecutarse **en orden**, ya que cada uno depende de los objetos creados por el anterior.
- Si se necesita reiniciar desde cero, basta con ejecutar nuevamente el archivo `01_Esquema_y_Datos.sql`, el cual elimina y recrea la base de datos completa (`DROP DATABASE IF EXISTS ecommerce_db`).
- El archivo `04_Seguridad.sql` requiere permisos de administrador en el servidor MySQL para crear usuarios y roles.