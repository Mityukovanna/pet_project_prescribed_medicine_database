CREATE DATABASE pharmacy_prescribed_medicine;
USE pharmacy_prescribed_medicine;

CREATE TABLE address (
    address_id INT PRIMARY KEY AUTO_INCREMENT,
    city VARCHAR(50),
    county VARCHAR(50),
    address_line_1 VARCHAR(50),
    address_line_2 VARCHAR(50),
    postcode VARCHAR(6)
);

CREATE TABLE patient (
    patient_id INT PRIMARY KEY AUTO_INCREMENT,
    address_id INT,
    FOREIGN KEY (address_id)
        REFERENCES address (address_id)
        ON DELETE SET NULL,
    NHS_number VARCHAR(15),
    name VARCHAR(50),
    phone VARCHAR(11),
    email VARCHAR(50),
    date_of_birth DATE,
    note VARCHAR(250)
);

CREATE TABLE doctor (
    doctor_id INT PRIMARY KEY AUTO_INCREMENT,
    address_id INT,
    FOREIGN KEY (address_id)
        REFERENCES address (address_id)
        ON DELETE SET NULL,
    doctor_index_number VARCHAR(10),
    name VARCHAR(50),
    phone VARCHAR(11),
    email VARCHAR(50),
    note VARCHAR(250)
);

CREATE TABLE medication_type(
    medication_type_id INT PRIMARY KEY AUTO_INCREMENT,
    medication_type_category VARCHAR(50)
);

CREATE TABLE medication(
    medication_id INT PRIMARY KEY AUTO_INCREMENT,
    medication_type_id INT,
    FOREIGN KEY (medication_type_id)
        REFERENCES medication_type(medication_type_id)
        ON DELETE SET NULL,
    medication_name VARCHAR(50),
    medication_code VARCHAR(20),
    medication_price DECIMAL(5, 2)
);

CREATE TABLE prescription_items(
    prescription_id INT,
    medication_id INT,
    FOREIGN KEY (medication_id)
        REFERENCES medication (medication_id)
        ON DELETE CASCADE,
    amount INT NOT NULL,
    note VARCHAR(250)
);

CREATE TABLE payment(
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    payment_type VARCHAR(30)
);

CREATE TABLE prescription(
    prescription_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT,
    doctor_id INT,
    payment_id INT,
    date_order DATE,
    date_payment DATE,

    FOREIGN KEY (patient_id)
        REFERENCES patient (patient_id)
        ON DELETE CASCADE,

    FOREIGN KEY (doctor_id)
        REFERENCES doctor (doctor_id)
        ON DELETE CASCADE,

    FOREIGN KEY (payment_id)
        REFERENCES payment(payment_id)
        ON DELETE SET NULL
);

/*CLEARING UP THE DATA*/

/* selecting all data from addresses that have duplicates*/
SELECT *
FROM address RIGHT JOIN (
    SELECT city, county, address_line_1, address_line_2, postcode, COUNT(*)
    FROM address
    GROUP BY city, county, address_line_1, address_line_2, postcode
    HAVING COUNT(*) > 1
) selected_addresses
ON address.city = selected_addresses.city
   AND address.county = selected_addresses.county
   AND address.address_line_1 = selected_addresses.address_line_1
   AND address.address_line_2 = selected_addresses.address_line_2
   AND address.postcode = selected_addresses.postcode
ORDER BY address.city, address_id;

/* Creating a table that contains duplicate address ids*/
CREATE TABLE duplicate_address_ids AS (
    SELECT address.address_id, address.city, address.county, address.address_line_1, address.address_line_2, address.postcode
    FROM address
             RIGHT JOIN (
        SELECT city, county, address_line_1, address_line_2, postcode, COUNT(*)
        FROM address
        GROUP BY city, county, address_line_1, address_line_2, postcode
        HAVING COUNT(*) > 1
    ) selected_addresses
                        ON address.city = selected_addresses.city
                            AND address.county = selected_addresses.county
                            AND address.address_line_1 = selected_addresses.address_line_1
                            AND address.address_line_2 = selected_addresses.address_line_2
                            AND address.postcode = selected_addresses.postcode
    ORDER BY address.city, address.address_id
);

/*Finding all patients and doctors who live in duplicate addresses*/
SELECT p.name AS person_name, p.address_id, 'Patient' AS person_type
FROM patient p
WHERE p.address_id IN (SELECT address_id FROM duplicate_address_ids)

UNION

SELECT d.name AS person_name, d.address_id, 'Doctor' AS person_type
FROM doctor d
WHERE d.address_id IN (SELECT address_id FROM duplicate_address_ids)
ORDER BY person_name;

/*Update the patient table to refer to the lowest address id of the duplicate.
  For example, Amos Troy has an address_id 15, however this address is a duplicate of the address 14
  Hence, after the update the patient's address_id will be changed to  14*/

UPDATE patient p
    JOIN duplicate_address_ids da ON p.address_id = da.address_id
    JOIN (
        SELECT MIN(address_id) AS keep_address_id, city, county, address_line_1, address_line_2, postcode
        FROM address
        GROUP BY city, county, address_line_1, address_line_2, postcode
    ) keep_addresses
    ON da.city = keep_addresses.city
        AND da.county = keep_addresses.county
        AND da.address_line_1 = keep_addresses.address_line_1
        AND da.address_line_2 = keep_addresses.address_line_2
        AND da.postcode = keep_addresses.postcode
SET p.address_id = keep_addresses.keep_address_id;

/*Updating Doctor database in a similar way*/
UPDATE doctor d
    JOIN duplicate_address_ids da ON d.address_id = da.address_id
    JOIN (
        SELECT MIN(address_id) AS keep_address_id, city, county, address_line_1, address_line_2, postcode
        FROM address
        GROUP BY city, county, address_line_1, address_line_2, postcode
        ) keep_addresses
    ON da.city = keep_addresses.city
        AND da.county = keep_addresses.county
        AND da.address_line_1 = keep_addresses.address_line_1
        AND da.address_line_2 = keep_addresses.address_line_2
        AND da.postcode = keep_addresses.postcode
SET d.address_id = keep_addresses.keep_address_id;

/*deleting the duplicated lines from the address, keeping only the ones with lower address_id*/
DELETE a
FROM address a
         JOIN duplicate_address_ids d ON a.address_id = d.address_id
         JOIN (
    SELECT MIN(address_id) AS keep_address_id, city, county, address_line_1, address_line_2, postcode
    FROM address
    GROUP BY city, county, address_line_1, address_line_2, postcode
) keep_addresses ON a.address_id != keep_addresses.keep_address_id
    AND a.city = keep_addresses.city
    AND a.county = keep_addresses.county
    AND a.address_line_1 = keep_addresses.address_line_1
    AND a.address_line_2 = keep_addresses.address_line_2
    AND a.postcode = keep_addresses.postcode;

/*adding a 'paid by NHS' method to all birth control medication*/
UPDATE prescription
SET payment_id = 4
WHERE payment_id IS NULL;

/* DATA ANALYSIS*/

/*Which doctor does have the most number of patients*/

SELECT d.name, d.doctor_id, d.phone, d.email, total_prescriptions
FROM doctor d RIGHT JOIN (
    SELECT pr.doctor_id, COUNT(pr.doctor_id) AS total_prescriptions
    FROM prescription pr
    GROUP BY pr.doctor_id
    ORDER BY COUNT(pr.doctor_id) DESC
    LIMIT 1) max_med_d_id
ON d.doctor_id = max_med_d_id.doctor_id;


/*What is the most frequently used method of payment*/
SELECT *
FROM payment p
WHERE p.payment_id IN (
    SELECT appearance.payment_id
    FROM (
             SELECT prescription.payment_id
             FROM prescription
             GROUP BY 1
             ORDER BY COUNT(prescription.payment_id) DESC
             LIMIT 1
         ) appearance
    );

/*List the information about the medicine requests with no payment date and show them by the date of order*/
SELECT *
FROM prescription
WHERE date_payment IS NULL
ORDER BY date_order;

/*What is an average cost of each prescription*/
SELECT ROUND(AVG(m.medication_price * pi.amount), 2) AS 'average price'
FROM prescription_items pi
JOIN medication m
ON m.medication_id = pi.medication_id;

/*list 3 most prescribed medicines*/
SELECT m.medication_name, COUNT(pi.medication_id) as 'times prescribed'
FROM prescription_items pi
         JOIN medication m
              ON m.medication_id = pi.medication_id
GROUP BY pi.medication_id
ORDER BY 2 DESC
LIMIT 3

/*List information about top 10 patients with the most number of prescriptions,
  sorted my amount of prescriptions and by the NHS number*/

SELECT pat.name, pat.NHS_number, pat.phone, pat.email, pat.date_of_birth, COUNT(pr.patient_id) AS 'number of orders', pat.note
FROM patient pat JOIN prescription pr
ON pat.patient_id = pr.patient_id
GROUP BY pr.patient_id
ORDER BY COUNT(pr.patient_id) DESC, pat.NHS_number
LIMIT 10
