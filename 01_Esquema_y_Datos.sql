-- ARCHIVO: 01_Esquema_y_Datos.sql

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);

CREATE TABLE proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(150) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(20)
);

CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria INT NOT NULL,
    id_proveedor INT NOT NULL,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    costo DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    sku VARCHAR(50) NOT NULL UNIQUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    id_sucursal INT NOT NULL DEFAULT 1,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
);

CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    contrasenia VARCHAR(255) NOT NULL,
    direccion_envio TEXT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_gastado DECIMAL(12,2) DEFAULT 0.00
);

CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_venta DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_congelado DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- INSERCIÓN DE DATOS AUTOMÁTICOS

-- 1. Categorías random
INSERT IGNORE INTO categorias (nombre, descripcion)
SELECT 
    CONCAT(
        ELT(FLOOR(1 + RAND() * 5), 'Juguetes', 'Ferretería', 'Mascotas', 'Jardinería', 'Belleza'),
        ' ', 
        FLOOR(RAND() * 900 + 100)
    ),
    CONCAT('Categoría generada #', FLOOR(RAND() * 9000 + 1000))
FROM information_schema.columns
LIMIT 20;

-- 2. Proveedores random
INSERT IGNORE INTO proveedores (nombre, email_contacto, telefono_contacto)
SELECT 
    CONCAT('Proveedor ', ELT(FLOOR(1 + RAND() * 5), 'Alpha', 'Beta', 'Gamma', 'Delta', 'Omega'), ' ', FLOOR(RAND() * 1000)),
    CONCAT('prov_', @rnum := IFNULL(@rnum, 0) + 1, '@empresas.com'),
    CONCAT('3', LPAD(FLOOR(RAND() * 1000000000), 9, '0'))
FROM information_schema.columns
LIMIT 50;

-- 3. Productos random
INSERT IGNORE INTO productos (id_categoria, id_proveedor, nombre, descripcion, precio, costo, stock, sku)
SELECT 
    FLOOR(1 + RAND() * (SELECT COUNT(*) FROM categorias)),
    FLOOR(1 + RAND() * (SELECT COUNT(*) FROM proveedores)),
    CONCAT(
        ELT(FLOOR(1 + RAND() * 8), 'Smart', 'Súper', 'Mega', 'Ultra', 'Pro', 'Mini', 'Eco', 'Gamer'),
        ' ',
        ELT(FLOOR(1 + RAND() * 8), 'Cámara', 'Reloj', 'Zapatos', 'Silla', 'Teclado', 'Mochila', 'Lámpara', 'Monitor'),
        ' X', FLOOR(RAND() * 999)
    ),
    'Un producto excelente generado aleatoriamente.',
    ROUND(50.00 + RAND() * 500.00, 2), 
    ROUND(10.00 + RAND() * 40.00, 2), 
    FLOOR(20 + RAND() * 100),
    CONCAT('SKU-', LPAD(FLOOR(RAND() * 999999), 6, '0'))
FROM information_schema.columns
LIMIT 200;

-- 4. Clientes random
INSERT IGNORE INTO clientes (nombre, apellido, email, contrasenia, direccion_envio)
SELECT 
    ELT(FLOOR(1 + RAND() * 10), 'Sebastián','Valentina','Alejandro','Natalia','Camilo','Daniela','Esteban','Manuela','Nicolás','Paola'),
    ELT(FLOOR(1 + RAND() * 10), 'Vargas','Moreno','Castro','Herrera','Jiménez','Medina','López','Ramos','Salcedo','Álvarez'),
    CONCAT('cliente_eco_', @rnum2 := IFNULL(@rnum2, 0) + 1, '@mail.com'),
    'password_super_segura',
    CONCAT(
        'Calle ', FLOOR(RAND() * 100 + 1), ' #', FLOOR(RAND() * 50 + 1), '-', FLOOR(RAND() * 99 + 1),
        ', ', ELT(FLOOR(1 + RAND() * 5), 'Bogotá','Medellín','Cali','Barranquilla','Bucaramanga')
    )
FROM information_schema.columns
LIMIT 200;

-- 5. Ventas random
INSERT IGNORE INTO ventas (id_cliente, fecha_venta, estado, total)
SELECT 
    FLOOR(1 + RAND() * (SELECT COUNT(*) FROM clientes)),
    DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY),
    ELT(FLOOR(1 + RAND() * 5), 'Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado'),
    0.00 
FROM information_schema.columns c1
JOIN information_schema.columns c2
LIMIT 300;

-- 6. Detalles de Ventas random
INSERT IGNORE INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
SELECT 
    FLOOR((SELECT MIN(id_venta) FROM ventas) + RAND() * ((SELECT MAX(id_venta) FROM ventas) - (SELECT MIN(id_venta) FROM ventas))),
    FLOOR(1 + RAND() * (SELECT COUNT(*) FROM productos)),
    FLOOR(1 + RAND() * 5), 
    ROUND(20.00 + RAND() * 300.00, 2) 
FROM information_schema.columns c1
JOIN information_schema.columns c2
LIMIT 800;

-- ACTUALIZAR LOS TOTALES DE LAS VENTAS
UPDATE ventas v
JOIN (
    SELECT id_venta, SUM(cantidad * precio_unitario_congelado) AS suma_total
    FROM detalle_ventas
    GROUP BY id_venta
) dv ON v.id_venta = dv.id_venta
SET v.total = dv.suma_total;