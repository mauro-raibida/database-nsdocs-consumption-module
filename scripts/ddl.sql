CREATE DATABASE IF NOT EXISTS `nsdocs_consumption`;

USE `nsdocs_consumption`;

CREATE TABLE IF NOT EXISTS `documents` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `id_company` int NOT NULL,
  `access_key` varchar(44) NOT NULL,
  `request_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `origin` enum('file','email','ws') NOT NULL,
  `document_type` enum('cfe','cte','cteos','mdfe','nfce','nfe','nfse') NOT NULL,
  `status` enum('ok','pending','error','non-existing') NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_access_key_company` (`access_key`,`id_company`) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `consumption` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_company` int NOT NULL,
  `consumption_date` date NOT NULL,
  `origin` enum('file','email','ws') NOT NULL,
  `document_type` enum('cfe','cte','cteos','mdfe','nfce','nfe','nfse') NOT NULL,
  `status` enum('ok','pending','error','non-existing') NOT NULL,
  `quantity` int NOT NULL DEFAULT 0,
  `total` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_company_type_origin_date_status` (`id_company`,`consumption_date`,`origin`,`document_type`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELIMITER //
CREATE PROCEDURE `update_company_consumption`(
	IN `id_company` INT,
	IN `quantity` INT,
	IN `consumption_date` DATE,
	IN `origin` enum('file','email','ws'),
	IN `document_type` enum('cfe','cte','cteos','mdfe','nfce','nfe','nfse'),
    IN `status` enum('ok','pending','error','non-existing')
)
begin
   declare id_consumption int default null;

   select id
     from consumption c
    where c.id_company = id_company
      and c.consumption_date = consumption_date
      and c.origin = origin
      and c.document_type = document_type
      and c.`status` = `status`
     into id_consumption;

   if id_consumption is null then
      insert ignore
        into consumption(`id_company`,`consumption_date`,`origin`,`document_type`,`status`,`quantity`,`total`)
      select d.id_company, d.request_date, d.origin, d.document_type, d.`status`, count(1), count(1)
        from documents d
       where d.id_company = id_company
         and d.origin = origin
         and d.document_type = document_type
         and d.request_date >= consumption_date
         and d.request_date < date_add(consumption_date, interval 1 day)
       group by d.origin, d.document_type
          on duplicate key
      update quantity = greatest(consumption.quantity + quantity, 0)
           , total = total + if(quantity > 0, 1, 0);
   else
      update consumption c
         set c.quantity = greatest(c.quantity + quantity, 0)
           , c.total = c.total + if(quantity > 0, 1, 0)
       where c.id = id_consumption;
   end if;
end//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_documents_ai` AFTER INSERT ON `documents` FOR EACH ROW begin
    call update_company_consumption(new.id_company, 1, new.request_date, new.origin, new.document_type, new.`status`);
end//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_documents_au` AFTER UPDATE ON `documents` FOR EACH ROW begin
    if(new.origin != old.origin or new.id_company != old.id_company or new.`status` != old.`status`) then
        call update_company_consumption(new.id_company, 1, new.request_date, new.origin, new.document_type, new.`status`);
        call update_company_consumption(old.id_company, -1, old.request_date, old.origin, old.document_type, old.`status`);
    end if;
end//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_documents_ad` AFTER DELETE ON `documents` FOR EACH ROW begin
    call update_company_consumption(old.id_company, -1, old.request_date, old.origin, old.document_type, old.`status`);
end//
DELIMITER ;
