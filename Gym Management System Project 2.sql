USE mydb2;

SELECT * FROM class_schedule;

ALTER TABLE class_schedule
MODIFY start_time TIME,
MODIFY end_time TIME;

ALTER TABLE tbl_equipment
MODIFY purchase_date DATE,
MODIFY last_maintenance_date DATE;

ALTER TABLE tbl_equipment_maintenance
MODIFY maintenance_date DATE;

ALTER TABLE tbl_member_membership
MODIFY start_date DATE,
MODIFY end_date DATE;

ALTER TABLE tbl_members
MODIFY date_of_birth DATE,
MODIFY join_date DATE;

ALTER TABLE tbl_trainers
MODIFY hire_date DATE;


DELIMITER $$

CREATE TRIGGER trg_update_last_maintenance
AFTER INSERT ON tbl_equipment_maintenance 
FOR EACH ROW
BEGIN 
UPDATE tbl_equipment 
SET last_maintenance_date = NEW.maintenance_date
WHERE equipment_id = NEW.equipment_id;
END$$

DELIMITER ; 


SHOW TRIGGERS;

DELIMITER $$

CREATE TRIGGER trg_prevent_overlapping_schedule 
BEFORE INSERT ON class_schedule 
FOR EACH ROW 
BEGIN 
DECLARE v_trainer_id INT;
SELECT trainer_id INTO v_trainer_id 
FROM tbl_classes
WHERE class_id = NEW.class_id;

IF EXISTS (SELECT 1 FROM class_schedule cs
JOIN tbl_classes c ON cs.class_id = c.class_id 
WHERE c.trainer_id = v_trainer_id 
AND cs.day_of_week = NEW.day_of_week
AND cs.start_time = NEW.start_time 
) THEN 
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Schedule conflict: Trainer already assigned at this time';
END IF ;
END $$

DELIMITER ;	

SET GLOBAL event_scheduler = ON;




CREATE TABLE tbl_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    log_message VARCHAR(255),
    log_date DATETIME
);


DELIMITER $$

CREATE EVENT ev_equipment_maintenance_reminder
ON SCHEDULE EVERY 1 DAY
DO 
BEGIN 
INSERT INTO tbl_logs(log_message,log_date)
SELECT 
CONCAT('Maintenance overdue for equipment id: ',equipment_id),
NOW()
FROM tbl_equipment 
WHERE last_maintenance_date <= DATE_SUB(CURDATE(), INTERVAL 90 DAY);
END $$

DELIMITER ;


DELIMITER $$

CREATE EVENT ev_expired_memberships_check
ON SCHEDULE EVERY 1 DAY 
DO
BEGIN 
INSERT INTO tbl_logs(log_message,log_date)
SELECT 
CONCAT('Membership expired for member id; ',member_id),
NOW()
FROM tbl_member_membership
WHERE end_date = CURDATE();
END $$

DELIMITER ;

SHOW EVENTS;



ALTER EVENT ev_equipment_maintenance_reminder
ON SCHEDULE EVERY 1 DAY;

SELECT * FROM tbl_logs;


-- 1. List all members with their current membership type.

SELECT a.member_id, a.first_name,a.last_name, b.membership_type
FROM tbl_members a 
JOIN tbl_member_membership c ON c.member_id = a.member_id
JOIN tbl_memberships b ON b.membership_id = c.membership_id
WHERE CURDATE() BETWEEN c.start_date AND c.end_date;

-- 2. Show member name, membership type, start_date, end_date.

SELECT a.first_name,a.last_name, b.membership_type, c.start_date,c.end_date
FROM tbl_members a
JOIN tbl_member_membership c ON c.member_id = a.member_id
JOIN tbl_memberships b ON b.membership_id = c.membership_id;

-- 3. List members whose membership expired.

SELECT a.first_name,a.last_name
FROM tbl_members a
JOIN tbl_member_membership b ON b.member_id = a.member_id 
WHERE b.end_date < CURDATE();

-- 4. Show trainers and the classes they conduct.

SELECT a.first_name,a.last_name,b.class_name
FROM tbl_trainers a
JOIN tbl_classes b ON b.trainer_id = a.trainer_id;

-- 5. List class schedules with trainer names.

SELECT  a.first_name,a.last_name, b.*
FROM class_schedule b
JOIN tbl_classes c ON c.class_id = b.class_id
LEFT JOIN tbl_trainers a ON a.trainer_id = c.trainer_id;

-- 6. Display memberships purchased with membership price.

SELECT a.first_name, a.last_name, b.membership_type as membership_purchased , b.price
FROM tbl_members a
LEFT JOIN tbl_member_membership c ON c.member_id = a.member_id
LEFT JOIN tbl_memberships b ON b.membership_id = c.membership_id; 

-- 7. Show classes that currently have no trainer assigned.

SELECT class_name 
FROM tbl_classes
WHERE trainer_id IS NULL;

-- 8. Display all equipment and their last maintenance date.

SELECT equipment_name, last_maintenance_date
FROM tbl_equipment;

-- 9. Show members with multiple membership renewals.

SELECT member_id, COUNT(*)  AS RENEWALS
FROM tbl_member_membership
GROUP BY member_id 
HAVING COUNT(*) > 1;

-- 10. List all trainers and total classes assigned.

SELECT a.trainer_id,a.first_name,a.last_name, COUNT(b.class_id)
FROM tbl_trainers a
LEFT JOIN tbl_classes b ON b.trainer_id = a.trainer_id
GROUP BY a.trainer_id,a.first_name,a.last_name;

--  11. Display classes with schedules and trainer details.

SELECT a.trainer_id, a.first_name,a.last_name,b.class_name,c.day_of_week,c.start_time,c.end_time
FROM tbl_trainers a 
LEFT JOIN tbl_classes b ON b.trainer_id = a.trainer_id
JOIN class_schedule c ON c.class_id = b.class_id;

-- 12. List members who joined after 2020 with membership type.

SELECT a.first_name,a.last_name, b.membership_type as membership_name
FROM tbl_members a 
JOIN tbl_member_membership c ON c.member_id = a.member_id
JOIN tbl_memberships b ON b.membership_id = c.membership_id 
WHERE a.join_date > '2020-01-01';

-- 13. Show equipment maintenance history with equipment names.

SELECT a.equipment_name, b.*
FROM tbl_equipment a
LEFT JOIN tbl_equipment_maintenance b ON b.equipment_id = a.equipment_id;

-- 14. List members who have never purchased a membership.

SELECT a.first_name,a.last_name
FROM tbl_members a
JOIN tbl_member_membership b ON b.member_id = a.member_id
WHERE a.member_id IS NULL;

-- 15. Show class schedules happening on Monday with trainer names.

SELECT a.first_name,a.last_name,b.day_of_week,c.class_name
FROM tbl_trainers a 
JOIN tbl_classes c ON c.trainer_id = a.trainer_id
JOIN class_schedule b ON b.class_id = c.class_id
WHERE b.day_of_week = 'Monday';

-- 16. Count total members in the gym.

SELECT COUNT(*) as total_members 
FROM tbl_members;

-- 17. Count total trainers hired

SELECT COUNT(*) as total_trainers FROM tbl_trainers;

-- 18. Find average membership duration.

SELECT AVG(duration_in_months) as avg_membership_duration FROM tbl_memberships;

-- 19. Calculate total membership revenue.

SELECT SUM(price) FROM tbl_memberships;

-- 20. Show revenue generated per membership type.

SELECT membership_type, SUM(price)
FROM tbl_memberships 
GROUP BY membership_type;

-- 21. Find trainer with maximum classes.

SELECT t.trainer_id,t.first_name,t.last_name,COUNT(c.class_id) as total_classes
FROM tbl_trainers t 
LEFT JOIN tbl_classes c ON c.trainer_id = t.trainer_id 
GROUP BY t.trainer_id,t.first_name,t.last_name
ORDER BY total_classes DESC
LIMIT 1;

-- 22. Count total equipment available.

SELECT COUNT(*) FROM tbl_equipment;

-- 23. Find number of classes per trainer.

SELECT trainer_id, COUNT(*) as total_classes
FROM tbl_classes 
GROUP BY trainer_id
ORDER BY trainer_id;

-- 24. Count memberships expiring this month.

SELECT COUNT(*) 
FROM tbl_member_membership
WHERE MONTH(end_date) = MONTH(CURDATE()); 

-- 25. Find average age of gym members.

SELECT AVG(timestampdiff(YEAR, date_of_birth, CURDATE())) as average_age
FROM tbl_members;

-- 26. Find members whose membership price is above average.

SELECT a.first_name,a.last_name, b.price
FROM tbl_members a
JOIN tbl_member_membership c on a.member_id = c.member_id 
JOIN tbl_memberships b on b.membership_id = c.membership_id 
WHERE b.price > (SELECT AVG(price) FROM tbl_memberships);

SELECT AVG(PRICE) FROM tbl_memberships;

-- 27. Show trainers who teach more classes than the average trainer.

SELECT trainer_id 
FROM tbl_classes
GROUP BY trainer_id
HAVING COUNT(*) > (SELECT AVG(cnt)
FROM (SELECT COUNT(*) as cnt FROM tbl_classes GROUP BY trainer_id)t);

-- 28. Find members with the latest membership end_date.

SELECT member_id
FROM tbl_member_membership
ORDER BY end_date DESC
LIMIT 1;

-- 29. List classes taught by the most experienced trainer.

SELECT a.first_name,a.last_name,b.class_name
FROM tbl_trainers a
JOIN tbl_classes b ON b.trainer_id = a.trainer_id
ORDER BY a.hire_date DESC
LIMIT 1;

--  30. Find members whose membership expires earliest

SELECT member_id, end_date
FROM tbl_member_membership
ORDER BY end_date;

-- 31. Find equipment maintained more than twice.

SELECT equipment_id 
FROM tbl_equipment_maintenance 
GROUP BY equipment_id 
HAVING COUNT(*) > 2;

-- 32. Show trainers whose hire_date is earlier than average hire date. 

SELECT first_name, last_name, hire_date
FROM tbl_trainers
WHERE hire_date < (SELECT AVG(hire_date) FROM tbl_trainers);

-- 33. Find memberships with price greater than average membership price.

SELECT membership_type, price
FROM tbl_memberships
WHERE price > (SELECT AVG(price) FROM tbl_memberships);

-- 34. Show members whose membership duration is maximum.

SELECT member_id
FROM tbl_member_membership
ORDER BY (end_date - start_date) DESC
LIMIT 4;

-- 35. Find classes scheduled more than once per week.

SELECT a.class_id, a.class_name
FROM tbl_classes a
JOIN class_schedule b ON b.class_id = a.class_id 
GROUP BY a.class_id, a.class_name
HAVING COUNT(a.class_id)>1;

-- 36. Rank members based on membership start date.

SELECT member_id, RANK() OVER (ORDER BY start_date) as rank_of_members
FROM tbl_member_membership;

-- 37. Rank trainers based on number of classes taught.

SELECT trainer_id,RANK() OVER (ORDER BY COUNT(*) DESC) as no_of_classes_taught
FROM tbl_classes
GROUP BY trainer_id;

-- 38. Find top 3 most popular membership plans.

SELECT a.membership_id, COUNT(*) as total_count, b.membership_type
FROM tbl_member_membership a
JOIN tbl_memberships b ON b.membership_id = a.membership_id
GROUP BY a.membership_id,b.membership_type
ORDER BY total_count DESC 
LIMIT 3;

-- 39. Show membership revenue ranking by membership type.

SELECT membership_id, membership_type, RANK() OVER(ORDER BY SUM(price) DESC) as membership_revenue
FROM tbl_memberships
GROUP BY membership_id, membership_type;

-- 40. Calculate running total of membership revenue.

SELECT a.member_id, b.membership_type,b.price, 
SUM(price) OVER(ORDER BY a.start_date) as running_total
FROM tbl_member_membership a
JOIN tbl_memberships b ON b.membership_id = a.membership_id;

-- 41. Rank equipment based on latest maintenance date.

SELECT equipment_id, equipment_name, last_maintenance_date, 
RANK() OVER(ORDER BY last_maintenance_date DESC) as maintenance_rank
FROM tbl_equipment;

-- 42. Find most active trainer per week.

SELECT * FROM (
SELECT c.trainer_id,t.first_name,t.last_name,d.day_of_week, COUNT(*) AS total_sessions,
RANK() OVER(partition by d.day_of_week order by COUNT(*) DESC) AS rnk
FROM class_schedule d
JOIN tbl_classes c ON d.class_id = c.class_id
JOIN tbl_trainers t ON t.trainer_id = c.trainer_id
GROUP BY c.trainer_id, t.first_name,t.last_name,d.day_of_week)x
WHERE rnk = 1;

-- 43. Show members joined per year with ranking.

SELECT first_name,last_name, YEAR(join_date) AS join_year,COUNT(*) AS total_members,
RANK() OVER(ORDER BY COUNT(*) DESC ) AS year_rank
FROM tbl_members
GROUP BY first_name, last_name, YEAR(join_date);


-- 44. Find top 5 members with longest memberships.

SELECT a.member_id, a.first_name,a.last_name, DATEDIFF(b.end_date,b.start_date) as duration
FROM tbl_member_membership b
JOIN tbl_members a ON a.member_id = b.member_id
ORDER BY duration DESC
LIMIT 5;

-- 45. Rank classes based on number of schedules.

SELECT a.class_id, a.class_name, COUNT(b.schedule_id) as total_schedules, RANK() OVER (ORDER BY COUNT(b.schedule_id)) as rnk
FROM tbl_classes a 
LEFT JOIN class_schedule b on a.class_id - b.class_id
GROUP BY a.class_id, a.class_name;

-- 46. Monthly membership sales report.

SELECT YEAR(start_date) as year,MONTH(start_date) as month,COUNT(*) AS total_sales
FROM tbl_member_membership
GROUP BY YEAR(start_date),MONTH(start_date)
ORDER BY year,month;

-- 47. Yearly member growth report.

SELECT YEAR(join_date) as year, COUNT(*) as total_members
FROM tbl_members
GROUP BY YEAR(join_date)
ORDER BY year;

-- 48. Trainer workload report.

SELECT t.trainer_id,t.first_name,t.last_name, COUNT(b.schedule_id) as total_sessions
FROM tbl_trainers t 
LEFT JOIN tbl_classes c ON c.trainer_id = t.trainer_id
LEFT JOIN class_schedule b ON b.class_id = c.class_id
GROUP BY t.trainer_id, t.first_name,t.last_name
ORDER BY total_sessions DESC;

-- 49. Equipment maintenance due report.	
-- “Due” = equipment not maintained for a long time (e.g., 90+ days)

SELECT equipment_id,equipment_name,last_maintenance_date
FROM tbl_equipment
WHERE last_maintenance_date <= date_sub(CURDATE(), INTERVAL 90 DAY);

-- 50. Class timetable dashboard report.

SELECT t.first_name,t.last_name,a.class_name,b.day_of_week,b.start_time
FROM tbl_classes a 
LEFT JOIN tbl_trainers t ON t.trainer_id = a.trainer_id
JOIN class_schedule b ON b.class_id = a.class_id
ORDER  BY b.day_of_week, b.start_time;


