-- ARCHIVO: 06_Eventos.sql
USE ecommerce_db;

-- Habilitamos el programador de eventos (っ◕‿◕)っ
SET GLOBAL event_scheduler = ON;

CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE,
    semana_fin DATE,
    total_pedidos INT,
    ingresos_totales DECIMAL(12,2),
    fecha_generado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lista_reabastecimiento (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    nombre_producto VARCHAR(150),
    stock_actual INT,
    fecha_generado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    id_resumen INT AUTO_INCREMENT PRIMARY KEY,
    fecha_dia DATE UNIQUE,
    total_pedidos INT,
    ingresos_totales DECIMAL(12,2),
    fecha_procesado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS kpis_mensuales (
    id_kpi INT AUTO_INCREMENT PRIMARY KEY,
    anio INT,
    mes INT,
    total_ventas DECIMAL(12,2),
    total_pedidos INT,
    nuevos_clientes INT,
    fecha_calculo DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_tamano_bd (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tamano_mb DECIMAL(10,2),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ranking_productos (
    id_ranking INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    nombre_producto VARCHAR(150),
    total_vendido INT,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lista_cumpleanos_dia (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    nombre_completo VARCHAR(205),
    email VARCHAR(150),
    fecha_generado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_actividad_sospechosa (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    descripcion TEXT,
    fecha_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reporte_rendimiento_proveedores (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    anio INT,
    mes INT,
    id_proveedor INT,
    nombre_proveedor VARCHAR(150),
    total_unidades_vendidas INT,
    dinero_generado DECIMAL(12,2),
    fecha_generado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS backup_ventas (
    id_venta INT,
    id_cliente INT,
    fecha_venta DATETIME,
    estado VARCHAR(50),
    total DECIMAL(10,2),
    fecha_backup DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 1. evt_generate_weekly_sales_report
-- Reporte de ventas semanal cada lunes (._.)
CREATE EVENT IF NOT EXISTS evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS DATE_ADD(CURDATE(), INTERVAL 1 DAY)
DO
    INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, total_pedidos, ingresos_totales)
    SELECT 
        DATE_SUB(CURDATE(), INTERVAL 7 DAY),
        CURDATE(),
        COUNT(id_venta),
        IFNULL(SUM(total), 0)
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    AND estado != 'Cancelado';


-- 2. evt_cleanup_temp_tables_daily
-- Limpia registros viejos de tablas temporales cada noche :D
CREATE EVENT IF NOT EXISTS evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 3 HOUR)
DO
    DELETE FROM lista_cumpleanos_dia WHERE fecha_generado < DATE_SUB(NOW(), INTERVAL 2 DAY);


-- 3. evt_archive_old_logs_monthly
-- Archiva logs de más de 6 meses cada mes ◕‿◕
CREATE EVENT IF NOT EXISTS evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS DATE_ADD(CURDATE(), INTERVAL 1 MONTH)
DO
    DELETE FROM log_cambios_precio WHERE fecha_cambio < DATE_SUB(NOW(), INTERVAL 6 MONTH);


-- 4. evt_deactivate_expired_promotions_hourly
-- Desactiva productos viejos sin ventas cada hora (─‿‿─)
CREATE EVENT IF NOT EXISTS evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
DO
    UPDATE productos
    SET activo = FALSE
    WHERE activo = TRUE
    AND id_producto NOT IN (SELECT DISTINCT id_producto FROM detalle_ventas)
    AND fecha_creacion < DATE_SUB(NOW(), INTERVAL 1 YEAR);


-- 5. evt_recalculate_customer_loyalty_tiers_nightly
-- Recalcula total_gastado de clientes cada noche O.O
CREATE EVENT IF NOT EXISTS evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 2 HOUR)
DO
    UPDATE clientes c
    JOIN (
        SELECT id_cliente, SUM(total) AS gasto_real
        FROM ventas
        WHERE estado = 'Entregado'
        GROUP BY id_cliente
    ) v ON c.id_cliente = v.id_cliente
    SET c.total_gastado = v.gasto_real;


-- 6. evt_generate_reorder_list_daily
-- Genera lista de reabastecimiento diaria (╥﹏╥)
CREATE EVENT IF NOT EXISTS evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 6 HOUR)
DO
    INSERT INTO lista_reabastecimiento (id_producto, nombre_producto, stock_actual)
    SELECT id_producto, nombre, stock
    FROM productos
    WHERE stock < 15 AND activo = TRUE;


-- 7. evt_rebuild_indexes_weekly
-- Optimiza tablas cada semana -_-
CREATE EVENT IF NOT EXISTS evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS DATE_ADD(CURDATE(), INTERVAL 7 DAY)
DO
    OPTIMIZE TABLE ventas;


-- 8. evt_suspend_inactive_accounts_quarterly
-- Revisa cuentas inactivas cada trimestre :)
CREATE EVENT IF NOT EXISTS evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
STARTS DATE_ADD(CURDATE(), INTERVAL 3 MONTH)
DO
    UPDATE clientes
    SET total_gastado = total_gastado
    WHERE id_cliente NOT IN (
        SELECT DISTINCT id_cliente FROM ventas
        WHERE fecha_venta > DATE_SUB(NOW(), INTERVAL 1 YEAR)
    );


-- 9. evt_aggregate_daily_sales_data
-- Agrega ventas del día anterior cada noche ◕‿◕
CREATE EVENT IF NOT EXISTS evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 1 HOUR)
DO
    INSERT INTO resumen_ventas_diarias (fecha_dia, total_pedidos, ingresos_totales)
    SELECT 
        DATE(fecha_venta),
        COUNT(id_venta),
        IFNULL(SUM(total), 0)
    FROM ventas
    WHERE DATE(fecha_venta) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
    AND estado != 'Cancelado'
    ON DUPLICATE KEY UPDATE
        total_pedidos = VALUES(total_pedidos),
        ingresos_totales = VALUES(ingresos_totales),
        fecha_procesado = NOW();


-- 10. evt_check_data_consistency_nightly
-- Cancela ventas pendientes sin detalle después de 48h (._.)
CREATE EVENT IF NOT EXISTS evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 4 HOUR)
DO
    UPDATE ventas
    SET estado = 'Cancelado'
    WHERE id_venta NOT IN (SELECT DISTINCT id_venta FROM detalle_ventas)
    AND estado = 'Pendiente de Pago'
    AND fecha_venta < DATE_SUB(NOW(), INTERVAL 48 HOUR);


-- 11. evt_send_birthday_greetings_daily
-- Lista clientes registrados hoy para enviarles cupón :D
CREATE EVENT IF NOT EXISTS evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 7 HOUR)
DO
    INSERT INTO lista_cumpleanos_dia (id_cliente, nombre_completo, email)
    SELECT id_cliente, CONCAT(nombre, ' ', apellido), email
    FROM clientes
    WHERE DAY(fecha_registro) = DAY(CURDATE())
    AND MONTH(fecha_registro) = MONTH(CURDATE());


-- 12. evt_update_product_rankings_hourly
-- Actualiza ranking de productos cada hora (─‿‿─)
CREATE EVENT IF NOT EXISTS evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
DO
    INSERT INTO ranking_productos (id_producto, nombre_producto, total_vendido)
    SELECT p.id_producto, p.nombre, IFNULL(SUM(dv.cantidad), 0) AS total_vendido
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto, p.nombre
    ORDER BY total_vendido DESC
    LIMIT 50;


-- 13. evt_backup_critical_tables_daily
-- Respalda ventas del día anterior cada noche O.O
CREATE EVENT IF NOT EXISTS evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 5 HOUR)
DO
    INSERT INTO backup_ventas (id_venta, id_cliente, fecha_venta, estado, total)
    SELECT id_venta, id_cliente, fecha_venta, estado, total
    FROM ventas
    WHERE DATE(fecha_venta) = DATE_SUB(CURDATE(), INTERVAL 1 DAY);


-- 14. evt_clear_abandoned_carts_daily
-- Cancela carritos abandonados de más de 72h (╥﹏╥)
CREATE EVENT IF NOT EXISTS evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 2 HOUR)
DO
    UPDATE ventas
    SET estado = 'Cancelado'
    WHERE estado = 'Pendiente de Pago'
    AND fecha_venta < DATE_SUB(NOW(), INTERVAL 72 HOUR);


-- 15. evt_calculate_monthly_kpis
-- Calcula KPIs del mes anterior el primer día de cada mes :)
CREATE EVENT IF NOT EXISTS evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS DATE_ADD(CURDATE(), INTERVAL 1 MONTH)
DO
    INSERT INTO kpis_mensuales (anio, mes, total_ventas, total_pedidos, nuevos_clientes)
    SELECT 
        YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)),
        MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)),
        IFNULL(SUM(v.total), 0),
        COUNT(v.id_venta),
        (SELECT COUNT(*) FROM clientes 
         WHERE YEAR(fecha_registro) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
         AND MONTH(fecha_registro) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)))
    FROM ventas v
    WHERE YEAR(v.fecha_venta) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
    AND MONTH(v.fecha_venta) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
    AND v.estado != 'Cancelado';


-- 16. evt_refresh_materialized_views_nightly
-- Recarga el ranking de productos (─‿‿─)
CREATE EVENT IF NOT EXISTS evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 3 HOUR)
DO
    INSERT INTO ranking_productos (id_producto, nombre_producto, total_vendido)
    SELECT p.id_producto, p.nombre, IFNULL(SUM(dv.cantidad), 0)
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto, p.nombre
    ORDER BY 3 DESC
    LIMIT 50;


-- 17. evt_log_database_size_weekly
-- Registra el tamaño de la BD semanalmente -_-
CREATE EVENT IF NOT EXISTS evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS DATE_ADD(CURDATE(), INTERVAL 2 HOUR)
DO
    INSERT INTO log_tamano_bd (tamano_mb)
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
    FROM information_schema.TABLES
    WHERE table_schema = 'ecommerce_db';


-- 18. evt_detect_fraudulent_activity_hourly
-- Detecta clientes con más de 5 pedidos pendientes en 1 hora ◕‿◕
CREATE EVENT IF NOT EXISTS evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
DO
    INSERT INTO log_actividad_sospechosa (id_cliente, descripcion)
    SELECT id_cliente, CONCAT('Múltiples pedidos pendientes en 1 hora: ', COUNT(*))
    FROM ventas
    WHERE estado = 'Pendiente de Pago'
    AND fecha_venta > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(*) > 5;


-- 19. evt_generate_supplier_performance_report_monthly
-- Reporte mensual de rendimiento de proveedores (っ◕‿◕)っ
CREATE EVENT IF NOT EXISTS evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS DATE_ADD(CURDATE(), INTERVAL 1 MONTH)
DO
    INSERT INTO reporte_rendimiento_proveedores (anio, mes, id_proveedor, nombre_proveedor, total_unidades_vendidas, dinero_generado)
    SELECT 
        YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)),
        MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)),
        prov.id_proveedor,
        prov.nombre,
        IFNULL(SUM(dv.cantidad), 0),
        IFNULL(SUM(dv.cantidad * dv.precio_unitario_congelado), 0)
    FROM proveedores prov
    INNER JOIN productos p ON prov.id_proveedor = p.id_proveedor
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    LEFT JOIN ventas v ON dv.id_venta = v.id_venta
        AND YEAR(v.fecha_venta) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
        AND MONTH(v.fecha_venta) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
    GROUP BY prov.id_proveedor, prov.nombre;


-- 20. evt_purge_soft_deleted_records_weekly
-- Elimina productos desactivados hace más de 30 días sin ventas O.O
CREATE EVENT IF NOT EXISTS evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS DATE_ADD(CURDATE(), INTERVAL 7 DAY)
DO
    DELETE FROM productos
    WHERE activo = FALSE
    AND fecha_modificacion < DATE_SUB(NOW(), INTERVAL 30 DAY)
    AND id_producto NOT IN (SELECT DISTINCT id_producto FROM detalle_ventas);

-- Reporte semanal
INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, total_pedidos, ingresos_totales)
SELECT DATE_SUB(CURDATE(), INTERVAL 7 DAY), CURDATE(), COUNT(id_venta), IFNULL(SUM(total), 0)
FROM ventas WHERE fecha_venta >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) AND estado != 'Cancelado';

-- Lista reabastecimiento
INSERT INTO lista_reabastecimiento (id_producto, nombre_producto, stock_actual)
SELECT id_producto, nombre, stock FROM productos WHERE stock < 15 AND activo = TRUE;

-- Resumen ventas diarias
INSERT INTO resumen_ventas_diarias (fecha_dia, total_pedidos, ingresos_totales)
SELECT DATE(fecha_venta), COUNT(id_venta), IFNULL(SUM(total), 0)
FROM ventas WHERE estado != 'Cancelado'
GROUP BY DATE(fecha_venta)
ON DUPLICATE KEY UPDATE total_pedidos = VALUES(total_pedidos), ingresos_totales = VALUES(ingresos_totales);

-- KPIs mensuales
INSERT INTO kpis_mensuales (anio, mes, total_ventas, total_pedidos, nuevos_clientes)
SELECT 
    anio,
    mes,
    total_ventas,
    total_pedidos,
    (SELECT COUNT(*) FROM clientes 
     WHERE YEAR(fecha_registro) = anio 
     AND MONTH(fecha_registro) = mes) AS nuevos_clientes
FROM (
    SELECT 
        YEAR(fecha_venta)        AS anio,
        MONTH(fecha_venta)       AS mes,
        IFNULL(SUM(total), 0)    AS total_ventas,
        COUNT(id_venta)          AS total_pedidos
    FROM ventas
    WHERE estado != 'Cancelado'
    GROUP BY YEAR(fecha_venta), MONTH(fecha_venta)
) AS resumen;

-- Tamaño BD
INSERT INTO log_tamano_bd (tamano_mb)
SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
FROM information_schema.TABLES WHERE table_schema = 'ecommerce_db';

-- Ranking productos
INSERT INTO ranking_productos (id_producto, nombre_producto, total_vendido)
SELECT p.id_producto, p.nombre, IFNULL(SUM(dv.cantidad), 0)
FROM productos p LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre ORDER BY 3 DESC LIMIT 50;

-- Actividad sospechosa (simulada)
INSERT INTO log_actividad_sospechosa (id_cliente, descripcion)
SELECT id_cliente, CONCAT('Múltiples pedidos pendientes: ', COUNT(*))
FROM ventas WHERE estado = 'Pendiente de Pago'
GROUP BY id_cliente HAVING COUNT(*) > 2;

-- Reporte rendimiento proveedores
INSERT INTO reporte_rendimiento_proveedores (anio, mes, id_proveedor, nombre_proveedor, total_unidades_vendidas, dinero_generado)
SELECT YEAR(CURDATE()), MONTH(CURDATE()), prov.id_proveedor, prov.nombre,
    IFNULL(SUM(dv.cantidad), 0), IFNULL(SUM(dv.cantidad * dv.precio_unitario_congelado), 0)
FROM proveedores prov
INNER JOIN productos p ON prov.id_proveedor = p.id_proveedor
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY prov.id_proveedor, prov.nombre;



-- Ver funciones
SHOW FUNCTION STATUS WHERE Db = 'ecommerce_db';

-- Ver procedimientos  
SHOW PROCEDURE STATUS WHERE Db = 'ecommerce_db';

-- Ver eventos
SHOW EVENTS FROM ecommerce_db;