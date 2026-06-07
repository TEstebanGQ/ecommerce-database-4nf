-- ARCHIVO: 04_Seguridad.sql
USE ecommerce_db;

-- Tabla de auditoría de precios (requerida por el rol Auditor_Financiero y los triggers) (Punto 6)
CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    precio_anterior DECIMAL(10,2),
    precio_nuevo DECIMAL(10,2),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
);

-- Vista para Atención al Cliente: oculta la columna de contraseña (Punto 13)
CREATE OR REPLACE VIEW v_info_clientes_basica AS 
SELECT 
    clientes.id_cliente, 
    clientes.nombre, 
    clientes.apellido, 
    clientes.direccion_envio 
FROM clientes;

-- Vista de Sucursal 1: aísla las ventas de esa sucursal (Punto 19)
CREATE OR REPLACE VIEW v_ventas_sucursal_1 AS 
SELECT 
    ventas.id_venta, 
    ventas.id_cliente, 
    ventas.fecha_venta, 
    ventas.total 
FROM ventas
INNER JOIN detalle_ventas ON ventas.id_venta = detalle_ventas.id_venta
INNER JOIN productos ON detalle_ventas.id_producto = productos.id_producto
WHERE productos.id_sucursal = 1;


-- 1. Crear el rol Administrador_Sistema con todos los privilegios.
CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema';

-- 2. Crear el rol Gerente_Marketing con acceso de solo lectura a ventas y clientes.
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.clientes TO 'Gerente_Marketing';

-- 3. Crear el rol Analista_Datos con acceso de solo lectura a todas las tablas excepto auditoría.
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
GRANT SELECT ON ecommerce_db.categorias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.proveedores TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Analista_Datos';

-- 4. Crear el rol Empleado_Inventario que solo pueda modificar stock y ubicación en productos.
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.productos TO 'Empleado_Inventario';
GRANT UPDATE(stock, id_sucursal) ON ecommerce_db.productos TO 'Empleado_Inventario';

-- 5. Crear el rol Atencion_Cliente que pueda ver ventas pero no modificar precios.
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';

-- 6. Crear el rol Auditor_Financiero con acceso de solo lectura a ventas, productos y logs.
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Auditor_Financiero';

-- 7. Crear usuario admin_user con rol administrador.
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Admin#Seguro2026!';
GRANT 'Administrador_Sistema' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Administrador_Sistema' TO 'admin_user'@'localhost';

-- 8. Crear usuario marketing_user con rol de marketing.
CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' IDENTIFIED BY 'Mktg#Seguro2026!';
GRANT 'Gerente_Marketing' TO 'marketing_user'@'localhost';
SET DEFAULT ROLE 'Gerente_Marketing' TO 'marketing_user'@'localhost';

-- 9. Crear usuario inventory_user con rol de inventario.
CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'Inven#Seguro2026!';
GRANT 'Empleado_Inventario' TO 'inventory_user'@'localhost';
SET DEFAULT ROLE 'Empleado_Inventario' TO 'inventory_user'@'localhost';

-- 10. Crear usuario support_user con rol de atención al cliente.
CREATE USER IF NOT EXISTS 'support_user'@'localhost' IDENTIFIED BY 'Supp#Seguro2026!';
GRANT 'Atencion_Cliente' TO 'support_user'@'localhost';
SET DEFAULT ROLE 'Atencion_Cliente' TO 'support_user'@'localhost';

-- 11. Impedir que Analista_Datos ejecute DELETE o TRUNCATE.
-- El rol Analista_Datos solo tiene GRANT SELECT, por lo que DELETE y TRUNCATE
-- están bloqueados por defecto sin necesidad de revocación explícita.
-- No se otorgaron esos privilegios en el punto 3, así que ya está cubierto.

-- 12. Otorgar al rol Gerente_Marketing permiso para ejecutar procedimientos almacenados.
GRANT EXECUTE ON ecommerce_db.* TO 'Gerente_Marketing';

-- 13. Dar acceso a la vista segura de clientes al rol Atencion_Cliente.
GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';

-- 14. Revocar UPDATE sobre precio al rol Empleado_Inventario.
-- En el punto 4 se otorgó UPDATE solo sobre (stock, id_sucursal), por lo que
-- precio nunca tuvo permiso. La revocación explícita queda documentada:
-- REVOKE UPDATE(precio) ON ecommerce_db.productos FROM 'Empleado_Inventario';

-- 15. Política de contraseñas seguras para todos los usuarios.
INSTALL COMPONENT 'file://component_validate_password';
SET GLOBAL validate_password.policy = 'MEDIUM';
SET GLOBAL validate_password.length = 8;
SET GLOBAL validate_password.mixed_case_count = 1;
SET GLOBAL validate_password.number_count = 1;
SET GLOBAL validate_password.special_char_count = 1;

-- 16. Asegurar que root no pueda conectarse remotamente.
DROP USER IF EXISTS 'root'@'%';

-- 17. Crear rol Visitante que solo vea la tabla productos.
CREATE ROLE IF NOT EXISTS 'Visitante';
GRANT SELECT ON ecommerce_db.productos TO 'Visitante';

-- 18. Crear usuario analista_user con límite de 500 consultas por hora.
CREATE USER IF NOT EXISTS 'analista_user'@'localhost' IDENTIFIED BY 'Data#Seguro2026!' WITH MAX_QUERIES_PER_HOUR 500;
GRANT 'Analista_Datos' TO 'analista_user'@'localhost';
SET DEFAULT ROLE 'Analista_Datos' TO 'analista_user'@'localhost';

-- 19. Dar acceso a la vista de sucursal al Gerente_Marketing.
GRANT SELECT ON ecommerce_db.v_ventas_sucursal_1 TO 'Gerente_Marketing';

-- 20. Auditar intentos de inicio de sesión fallidos.
-- Requiere el plugin connection_control. En Linux/Windows se activa agregando
-- plugin-load-add=connection_control.so en my.ini o my.cnf.
-- Una vez activo se configura con:
/*
SET GLOBAL connection_control_failed_connections_threshold = 3;
SET GLOBAL connection_control_min_connection_delay = 1000;
*/
-- Intente pero no fui capaz sinceramente
-- Se aplica toda la seguridad de forma inmediata
FLUSH PRIVILEGES;