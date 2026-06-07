-- ARCHIVO: 05_Triggers.sql
USE ecommerce_db;


CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    precio_anterior DECIMAL(10,2),
    precio_nuevo DECIMAL(10,2),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS log_nuevos_clientes (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    nombre_completo VARCHAR(205),
    email VARCHAR(150),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_cambios_estado_venta (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS alertas_stock (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    nombre_producto VARCHAR(150),
    stock_actual INT,
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ventas_archivadas (
    id_venta INT PRIMARY KEY,
    id_cliente INT,
    fecha_venta DATETIME,
    estado VARCHAR(50),
    total DECIMAL(10,2),
    fecha_archivado DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS referidos (
    id_referido INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_referidor INT NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_cambios_usuario (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(255),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    ejecutado_por VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS registro_permisos (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100),
    accion VARCHAR(50),
    detalle TEXT,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Columnas extra que los triggers necesitan y que no están en el esquema base
ALTER TABLE clientes ADD COLUMN fecha_ultimo_pedido DATETIME NULL;
ALTER TABLE productos ADD COLUMN fecha_modificacion DATETIME NULL;
ALTER TABLE categorias ADD COLUMN total_productos INT DEFAULT 0;

-- Categoría General para el trigger #19
INSERT IGNORE INTO categorias (nombre, descripcion)
VALUES ('General', 'Categoría por defecto para productos sin clasificar.');



-- MySQL solo permite un trigger por evento+tiempo+tabla.
-- Los triggers #7 (fecha_modificacion), #8 (stock negativo) y
-- #12 (precio cero) se fusionan en uno solo. (っ◕‿◕)っ


-- 7 + 8 + 12 fusionados: trg_before_update_productos
CREATE TRIGGER trg_before_update_productos
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    -- (#12) Impide precio en cero o negativo
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor que cero.';
    END IF;
    -- (#8) Impide stock negativo
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El stock no puede quedar en valor negativo.';
    END IF;
    -- (#7) Actualiza fecha de modificación automáticamente
    SET NEW.fecha_modificacion = NOW();
END;


-- 1. trg_audit_precio_producto_after_update
-- Guarda un log cada vez que el precio de un producto cambia (._.)
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario)
        VALUES (OLD.id_producto, OLD.precio, NEW.precio, USER());
    END IF;
    -- (#13) Alerta si el stock baja del umbral de 10 unidades
    IF NEW.stock < 10 AND OLD.stock >= 10 THEN
        INSERT INTO alertas_stock (id_producto, nombre_producto, stock_actual)
        VALUES (NEW.id_producto, NEW.nombre, NEW.stock);
    END IF;
END;

-- Los triggers #9 (capitalizar) y #15 (validar email) se fusionan. (─‿‿─)

-- 9 + 15 fusionados: trg_before_insert_clientes
CREATE TRIGGER trg_before_insert_clientes
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    -- (#15) Valida formato de email
    IF NEW.email NOT LIKE '%@%.%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El formato del email del cliente no es válido.';
    END IF;
    -- (#9) Capitaliza nombre y apellido
    SET NEW.nombre  = CONCAT(UPPER(SUBSTRING(NEW.nombre, 1, 1)),  LOWER(SUBSTRING(NEW.nombre, 2)));
    SET NEW.apellido = CONCAT(UPPER(SUBSTRING(NEW.apellido, 1, 1)), LOWER(SUBSTRING(NEW.apellido, 2)));
END;

.

-- 2. trg_check_stock_before_insert_venta
-- Verifica que haya stock suficiente antes de insertar un detalle de venta :(
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock_actual INT;
    SELECT stock INTO v_stock_actual FROM productos WHERE id_producto = NEW.id_producto;
    IF v_stock_actual < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para completar la venta.';
    END IF;
END;


-- 3. trg_update_stock_after_insert_venta
-- Descuenta el stock del producto después de registrar el detalle de una venta ◕‿◕
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END;


-- 4. trg_prevent_delete_categoria_with_products
-- Impide borrar una categoría si tiene productos asignados O.O
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_total INT;
    SELECT COUNT(*) INTO v_total FROM productos WHERE id_categoria = OLD.id_categoria;
    IF v_total > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar la categoría porque tiene productos asociados.';
    END IF;
END;


-- 5. trg_log_new_customer_after_insert
-- Registra en auditoría cada cliente nuevo :D
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_nuevos_clientes (id_cliente, nombre_completo, email, fecha_registro)
    VALUES (NEW.id_cliente, CONCAT(NEW.nombre, ' ', NEW.apellido), NEW.email, NEW.fecha_registro);
END;


-- 6. trg_update_total_gastado_cliente
-- Suma al total_gastado del cliente cuando una venta pasa a Entregado (─‿‿─)
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Entregado' AND OLD.estado <> 'Entregado' THEN
        UPDATE clientes
        SET total_gastado = total_gastado + NEW.total,
            fecha_ultimo_pedido = NEW.fecha_venta
        WHERE id_cliente = NEW.id_cliente;
    END IF;
    -- (#11) Audita cambios de estado
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO log_cambios_estado_venta (id_venta, estado_anterior, estado_nuevo, usuario)
        VALUES (NEW.id_venta, OLD.estado, NEW.estado, USER());
    END IF;
END;


-- 10. trg_recalculate_total_venta_on_detalle_change
-- Recalcula el total de la venta cuando se modifica un detalle o.o
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER UPDATE ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = (
        SELECT IFNULL(SUM(cantidad * precio_unitario_congelado), 0)
        FROM detalle_ventas
        WHERE id_venta = NEW.id_venta
    )
    WHERE id_venta = NEW.id_venta;
END;


-- 14. trg_archive_deleted_venta
-- Mueve la venta a la tabla de archivo antes de eliminarla -_-
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas (id_venta, id_cliente, fecha_venta, estado, total)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.estado, OLD.total);
END;


-- 16. trg_update_last_order_date_customer
-- Actualiza la fecha del último pedido al crear una venta nueva :)
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET fecha_ultimo_pedido = NEW.fecha_venta
    WHERE id_cliente = NEW.id_cliente;
END;


-- 17. trg_prevent_self_referral
-- Impide que un cliente se refiera a sí mismo en el programa de referidos (╥﹏╥)
CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON referidos
FOR EACH ROW
BEGIN
    IF NEW.id_cliente = NEW.id_referidor THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Un cliente no puede referenciarse a sí mismo.';
    END IF;
END;


-- 18. trg_log_permission_changes
-- Registra cambios de permisos insertados en la tabla auxiliar registro_permisos ◕‿◕
CREATE TRIGGER trg_log_permission_changes
AFTER INSERT ON registro_permisos
FOR EACH ROW
BEGIN
    INSERT INTO log_cambios_usuario (descripcion, ejecutado_por)
    VALUES (CONCAT('Permiso ', NEW.accion, ' para usuario: ', NEW.usuario, ' — ', NEW.detalle), USER());
END;


-- 19. trg_assign_default_category_on_null
-- Asigna categoría General si se inserta un producto sin categoría (っ◕‿◕)っ
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = (SELECT id_categoria FROM categorias WHERE nombre = 'General' LIMIT 1);
    END IF;
END;


-- 20a. trg_update_producto_count_insert
-- Incrementa el contador de productos de la categoría al insertar O.O
CREATE TRIGGER trg_update_producto_count_insert
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET total_productos = total_productos + 1
    WHERE id_categoria = NEW.id_categoria;
END;


-- 20b. trg_update_producto_count_delete
-- Decrementa el contador de productos de la categoría al eliminar O.O
CREATE TRIGGER trg_update_producto_count_delete
AFTER DELETE ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET total_productos = GREATEST(total_productos - 1, 0)
    WHERE id_categoria = OLD.id_categoria;
END;