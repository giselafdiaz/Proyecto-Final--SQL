CREATE DATABASE Ingreso;

USE Ingreso;

-- Crear la tabla alumnos con sus datos personales

CREATE TABLE alumnos (
		id_alumno INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
        nombre VARCHAR (30) NOT NULL,
        apellido VARCHAR (40) NOT NULL,
        email VARCHAR (100) UNIQUE DEFAULT NULL,
        dni INT UNIQUE NOT NULL,
        edad INT,
        telefono VARCHAR (20) UNIQUE DEFAULT NULL,
        nacionalidad VARCHAR (30) DEFAULT "argentino", 
        provincia VARCHAR (30)
);

-- Crear la tabla alumnos_secundaria con datos de su educacuón en nivel secundario

CREATE TABLE alumnos_secundaria (
		id_alumno INT,
        tipo1 VARCHAR(2) NOT NULL,
        tipo2 VARCHAR (2) NOT NULL,
		PRIMARY KEY (id_alumno),
		FOREIGN KEY (id_alumno) REFERENCES alumnos(id_alumno)
);

-- Crear la tabla cursos para los distintos tipos de cursos de ingreso que se dictan en la facultad

CREATE TABLE cursos (
	id_curso INT PRIMARY KEY AUTO_INCREMENT,
    nombre_curso VARCHAR(50) NOT NULL
);

-- Insertar en la tabla cursoso los nombres de los distintos tipos de cursos de ingreso 

INSERT INTO cursos (nombre_curso) VALUES 
	("Intensivo febrero"),
    ("Regular 1er cuat"),
	("Regular 2do cuat"),
    ("Suficiencia");

-- Crear la tabla inscripciones donde se almacenaran los datos relacionados a la inscripción del alumno 
-- en un curso de ingreso o examen de suficiencia

CREATE TABLE inscripciones (
	id_alumno INT,
    id_curso INT,
    modalidad VARCHAR(1), 
    turno VARCHAR(1), 
    inscription_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_alumno, id_curso),
    FOREIGN KEY (id_alumno) REFERENCES alumnos(id_alumno),
    FOREIGN KEY (id_curso) REFERENCES cursos(id_curso)
);

-- Crear la tabla examen donde se identifican los distintos examenes que pueden rendir los alumnos

CREATE TABLE examen (
	id_examen INT PRIMARY KEY AUTO_INCREMENT,
	nombre_examen VARCHAR(30)
); 

-- Inserta en la tabla examen los nombres de los examenes

INSERT INTO examen(nombre_examen) VALUES 
("Primer Parcial"),
("Segundo Parcial"),
("Recuperación Primer Parcial"),
("Recuperación Segundo Parcial"),
("Primera Recuperación Integral"),
("Segunda Recuperación Integral"),
("Suficiencia");

-- Crea la tabla notas donde se almacenará toda la información de los exámenes que rindió cada alumno

CREATE TABLE notas (
	id_alumno INT,
    id_curso INT,
    id_examen INT,
    anio INT(4) NOT NULL,
    nota DECIMAL(10,2),
    PRIMARY KEY (id_alumno, id_curso, id_examen),
    FOREIGN KEY (id_alumno) REFERENCES alumnos(id_alumno),
    FOREIGN KEY (id_curso) REFERENCES cursos(id_curso),
    FOREIGN KEY (id_examen) REFERENCES examen(id_examen)
    );
    
-- Crear la tabla resumen de estado de curso y promedio

CREATE TABLE estado_curso_alumnos (
    id_alumno INT NOT NULL,
    id_curso INT NOT NULL,
    anio INT NOT NULL,
    promedio_notas DECIMAL(5,2),
    estado_curso VARCHAR(15),
    PRIMARY KEY (id_alumno, id_curso, anio),
    FOREIGN KEY (id_alumno) REFERENCES alumnos(id_alumno),
    FOREIGN KEY (id_curso) REFERENCES cursos(id_curso)
);

-- Función para calcular el promedio de notas de un alumno en un curso y en un año en específico

DELIMITER //
CREATE FUNCTION calcular_promedio_notas(
    p_alumno_id INT,
    p_curso_id INT,
    p_anio INT
) RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE promedio DECIMAL(5,2);

    SELECT AVG(nota) INTO promedio
    FROM notas
    WHERE id_alumno = p_alumno_id
      AND id_curso = p_curso_id
      AND anio = p_anio;

    RETURN IFNULL(promedio, 0);
END //


-- Función para calcular si el alumno aprobó o desaprobó el curso

CREATE FUNCTION calcular_estado_curso(
    p_alumno_id INT,
    p_curso_id INT,
    p_anio INT
) RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE resultado VARCHAR(15);

    -- Caso especial: curso de suficiencia (id_curso = 4)
    IF p_curso_id = 4 THEN
        IF EXISTS (
            SELECT 1 FROM notas n
            JOIN examen e ON n.id_examen = e.id_examen
            WHERE n.id_alumno = p_alumno_id
              AND n.id_curso = p_curso_id
              AND n.anio = p_anio
              AND e.nombre_examen = 'Suficiencia'
              AND n.nota >= 5
        ) THEN
            SET resultado = 'Aprobado';
        ELSE
            SET resultado = 'Desaprobado';
        END IF;

    ELSEIF (
        (SELECT COUNT(*) FROM notas n
         JOIN examen e ON n.id_examen = e.id_examen
         WHERE n.id_alumno = p_alumno_id AND n.id_curso = p_curso_id AND n.anio = p_anio 
           AND e.nombre_examen IN ('Primer Parcial', 'Segundo Parcial') AND n.nota >= 5) = 2
        OR
        (SELECT COUNT(*) FROM notas n
         JOIN examen e ON n.id_examen = e.id_examen
         WHERE n.id_alumno = p_alumno_id AND n.id_curso = p_curso_id AND n.anio = p_anio
           AND e.nombre_examen IN ('Recuperación Primer Parcial', 'Recuperación Segundo Parcial', 'Primera Recuperación Integral')
           AND n.nota >= 5) >= 1
        OR
        (SELECT COUNT(*) FROM notas n
         JOIN examen e ON n.id_examen = e.id_examen
         WHERE n.id_alumno = p_alumno_id AND n.id_curso = p_curso_id AND n.anio = p_anio 
           AND e.nombre_examen = 'Segunda Recuperación Integral'
           AND n.nota >= 5) >= 1
    ) THEN
        SET resultado = 'Aprobado';
    ELSE
        SET resultado = 'Desaprobado';
    END IF;

    RETURN resultado;
END //
DELIMITER ;

-- Crear tabla con historial de notas

CREATE TABLE historial_notas (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    id_alumno INT,
    id_curso INT,
    id_examen INT,
    nota_anterior DECIMAL(5,2),
    nota_nueva DECIMAL(5,2),
    fecha_cambio DATETIME
);

-- Trigger para registrar automáticamente el historial de cambio de notas

DELIMITER //
CREATE TRIGGER trg_historial_actualizacion_nota
AFTER UPDATE ON notas
FOR EACH ROW
BEGIN
    IF OLD.nota <> NEW.nota THEN
        INSERT INTO historial_notas (
		id_alumno,
		id_curso,
		id_examen,
		nota_anterior,
		nota_nueva,
		fecha_cambio
        )
        VALUES 
		(NEW.id_alumno,
		NEW.id_curso,
		NEW.id_examen,
		OLD.nota,
		NEW.nota,
		NOW()
        );
    END IF;
END;
//


-- Stored Procedure para llenar la tabla estado_curso_alumno

DELIMITER //

CREATE PROCEDURE actualizar_estado_curso_alumnos()
BEGIN
    INSERT INTO estado_curso_alumnos (id_alumno, id_curso, anio, promedio_notas, estado_curso)
    SELECT 
        n.id_alumno,
        n.id_curso,
        n.anio,
        calcular_promedio_notas(n.id_alumno, n.id_curso, n.anio),
        calcular_estado_curso(n.id_alumno, n.id_curso, n.anio)
    FROM (
        SELECT DISTINCT id_alumno, id_curso, anio FROM notas WHERE anio IS NOT NULL
    ) AS n
    ON DUPLICATE KEY UPDATE
        promedio_notas = VALUES(promedio_notas),
        estado_curso = VALUES(estado_curso);
END //

DELIMITER ;

-- Vistas para analizar el impacto de distintos factores en el rendimiento académico del estudiante

-- Impacto del tipo de curso (suficiencia, regular, intensivo y cuatrimestre)

CREATE or replace VIEW vista_impacto_tipo_curso AS
SELECT c.nombre_curso, ea.estado_curso, ea.anio, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM estado_curso_alumnos ea
JOIN cursos c ON ea.id_curso = c.id_curso
GROUP BY c.nombre_curso, ea.estado_curso, ea.anio;

-- Impacto del turno (mañana o tarde)

CREATE VIEW vista_impacto_turno AS
SELECT i.turno, ea.estado_curso, ea.anio, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM inscripciones i
JOIN estado_curso_alumnos ea ON ea.id_alumno = i.id_alumno AND ea.id_curso = i.id_curso
GROUP BY i.turno, ea.estado_curso, ea.anio;


-- Impacto de la institución proveniente (pública o privada, técnica o no técnica)

CREATE VIEW vista_impacto_institucion AS
SELECT s.tipo1, s.tipo2, ea.estado_curso, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM alumnos_secundaria s
JOIN estado_curso_alumnos ea ON s.id_alumno = ea.id_alumno
GROUP BY s.tipo1, s.tipo2, ea.estado_curso;

-- Impacto del tipo de cursillo (presencial o virtual)

CREATE VIEW vista_impacto_modalidad AS
SELECT i.modalidad, ea.estado_curso, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM inscripciones i
JOIN estado_curso_alumnos ea ON ea.id_alumno = i.id_alumno AND ea.id_curso = i.id_curso
GROUP BY i.modalidad, ea.estado_curso;

-- Impacto de los contenidos de los parciales (Primer parcial y segundo parcial)
 
CREATE VIEW vista_notas_parciales AS
SELECT 
  e.nombre_examen,
  COUNT(*) AS total,
  SUM(CASE WHEN n.nota >= 5 THEN 1 ELSE 0 END) AS aprobados,
  SUM(CASE WHEN n.nota < 5 THEN 1 ELSE 0 END) AS desaprobados,
  AVG(n.nota) AS promedio
FROM notas n
JOIN examen e ON n.id_examen = e.id_examen
WHERE e.nombre_examen IN ('Primer Parcial', 'Segundo Parcial')
GROUP BY e.nombre_examen;


-- Impacto de la provincia en argentinos

CREATE VIEW vista_impacto_provincia AS
SELECT a.provincia, ea.estado_curso, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM alumnos a
JOIN estado_curso_alumnos ea ON a.id_alumno = ea.id_alumno
WHERE
    a.nacionalidad = 'argentino'
GROUP BY a.provincia, ea.estado_curso;

-- Impacto de la nacionalidad del aspirante

CREATE VIEW vista_impacto_nacionalidad AS
SELECT a.nacionalidad, ea.estado_curso, COUNT(*) AS cantidad, AVG(ea.promedio_notas) AS promedio_notas_grupal
FROM alumnos a
JOIN estado_curso_alumnos ea ON a.id_alumno = ea.id_alumno
GROUP BY a.nacionalidad, ea.estado_curso;

-- Crea reporte anual

DELIMITER //
CREATE PROCEDURE generar_reporte_estado_curso(
    IN anio INT
   )
BEGIN
    SELECT 
        a.id_alumno,
        CONCAT(a.nombre, ' ', a.apellido) AS nombre_completo,
        c.nombre_curso,
        ea.promedio_notas,
        ea.estado_curso,
        a.provincia,
        a.nacionalidad,
        i.turno,
        i.modalidad,
        s.tipo1 AS institucion_tipo,
        s.tipo2 AS orientacion
    FROM estado_curso_alumnos ea
    JOIN alumnos a ON a.id_alumno = ea.id_alumno
    JOIN cursos c ON c.id_curso = ea.id_curso
    LEFT JOIN inscripciones i ON i.id_alumno = a.id_alumno AND i.id_curso = c.id_curso
    LEFT JOIN alumnos_secundaria s ON s.id_alumno = a.id_alumno
    WHERE ea.anio = anio;
END;
//

-- drop database ingreso;







