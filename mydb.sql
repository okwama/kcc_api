-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Sep 04, 2025 at 06:57 AM
-- Server version: 10.6.23-MariaDB-cll-lve
-- PHP Version: 8.4.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `impulsep_kcc`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `CreateBasicOrder` (IN `p_client_id` INT, IN `p_salesrep_id` INT, IN `p_notes` TEXT, IN `p_so_number` VARCHAR(20), IN `p_total_amount` DECIMAL(15,2), OUT `p_order_id` INT, OUT `p_success` TINYINT, OUT `p_error_message` TEXT)   proc_label: BEGIN
    DECLARE v_order_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Database error occurred';
    END;

    START TRANSACTION;

    -- Validate client exists
    IF NOT EXISTS (SELECT 1 FROM Clients WHERE id = p_client_id AND status = 0) THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Invalid client or client is inactive';
        LEAVE proc_label;
    END IF;

    -- Validate sales rep exists
    IF NOT EXISTS (SELECT 1 FROM SalesRep WHERE id = p_salesrep_id AND status = 1) THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Invalid sales rep or sales rep is inactive';
        LEAVE proc_label;
    END IF;

    -- Insert into sales_orders
    INSERT INTO sales_orders (
        so_number,
        client_id,
        order_date,
        expected_delivery_date,
        subtotal,
        tax_amount,
        total_amount,
        net_price,
        notes,
        salesrep,
        rider_id,
        assigned_at,
        status,
        my_status
    ) VALUES (
        p_so_number,
        p_client_id,
        CURDATE(),
        DATE_ADD(CURDATE(), INTERVAL 7 DAY),
        p_total_amount,
        0,
        p_total_amount,
        p_total_amount,
        p_notes,
        p_salesrep_id,
        0,
        NULL,
        'draft',
        0
    );

    SET v_order_id = LAST_INSERT_ID();

    COMMIT;

    SET p_order_id = v_order_id;
    SET p_success = TRUE;
    SET p_error_message = NULL;

END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `GetClockSessions` (IN `p_userId` INT, IN `p_startDate` DATE, IN `p_endDate` DATE, IN `p_limit` INT)   BEGIN
    -- Set default limit if NULL
    SET p_limit = COALESCE(p_limit, 50);
    
    -- Get session history with optional date range
    SELECT 
        id,
        userId,
        sessionStart,
        sessionEnd,
        duration,
        status,
        timezone,
        -- Formatted fields for frontend
        DATE_FORMAT(sessionStart, '%Y-%m-%d %H:%i:%s') as formattedStart,
        DATE_FORMAT(sessionEnd, '%Y-%m-%d %H:%i:%s') as formattedEnd,
        CASE 
            WHEN duration >= 60 THEN CONCAT(FLOOR(duration/60), 'h ', MOD(duration, 60), 'm')
            ELSE CONCAT(duration, 'm')
        END as formattedDuration,
        CASE WHEN status = 1 THEN 1 ELSE 0 END as isActive
    FROM LoginHistory 
    WHERE userId = p_userId
        AND (p_startDate IS NULL OR DATE(sessionStart) >= p_startDate)
        AND (p_endDate IS NULL OR DATE(sessionStart) <= p_endDate)
    ORDER BY sessionStart DESC
    LIMIT p_limit;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `GetJourneyPlans` (IN `p_userId` INT, IN `p_status` INT, IN `p_targetDate` DATE, IN `p_page` INT, IN `p_limit` INT, IN `p_offset` INT)   BEGIN
    -- Set default values
    SET p_page = COALESCE(p_page, 1);
    SET p_limit = COALESCE(p_limit, 20);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get journey plans with client and user information
    SELECT 
        jp.id,
        jp.userId,
        jp.clientId,
        jp.date,
        jp.time,
        jp.status,
        jp.checkInTime,
        jp.latitude,
        jp.longitude,
        jp.imageUrl,
        jp.notes,
        jp.checkoutLatitude,
        jp.checkoutLongitude,
        jp.checkoutTime,
        jp.showUpdateLocation,
        jp.routeId,
        -- Client information
        c.id as 'client.id',
        c.name as 'client.name',
        c.contact as 'client.contact',
        c.email as 'client.email',
        c.address as 'client.address',
        c.status as 'client.status',
        c.route_id as 'client.route_id',
        c.route_name as 'client.route_name',
        c.countryId as 'client.countryId',
        c.region_id as 'client.region_id',
        c.created_at as 'client.created_at',
        -- User/SalesRep information
        sr.id as 'user.id',
        sr.name as 'user.name',
        sr.email as 'user.email',
        sr.phoneNumber as 'user.phoneNumber',
        sr.role as 'user.role',
        sr.status as 'user.status',
        sr.countryId as 'user.countryId',
        sr.region_id as 'user.region_id',
        sr.route_id as 'user.route_id',
        sr.route as 'user.route',
        sr.createdAt as 'user.createdAt',
        sr.updatedAt as 'user.updatedAt'
    FROM JourneyPlan jp
    LEFT JOIN Clients c ON jp.clientId = c.id
    LEFT JOIN SalesRep sr ON jp.userId = sr.id
    WHERE (p_userId = 0 OR jp.userId = p_userId)
        AND (p_status = -1 OR jp.status = p_status)
        AND (p_targetDate IS NULL OR DATE(jp.date) = p_targetDate)
    ORDER BY jp.date DESC, jp.time DESC
    LIMIT p_limit OFFSET p_offset;
    
    -- Get total count for pagination
    SELECT COUNT(*) as total
    FROM JourneyPlan jp
    WHERE (p_userId = 0 OR jp.userId = p_userId)
        AND (p_status = -1 OR jp.status = p_status)
        AND (p_targetDate IS NULL OR DATE(jp.date) = p_targetDate);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `account_category`
--

CREATE TABLE `account_category` (
  `id` int(3) NOT NULL,
  `name` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `account_category`
--

INSERT INTO `account_category` (`id`, `name`) VALUES
(1, 'Assets'),
(2, 'Liabilities'),
(3, 'Equity'),
(4, 'Revenue'),
(5, 'Expenses');

-- --------------------------------------------------------

--
-- Table structure for table `account_ledger`
--

CREATE TABLE `account_ledger` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `date` datetime NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `reference_type` varchar(50) DEFAULT NULL,
  `reference_id` int(11) DEFAULT NULL,
  `debit` decimal(15,2) DEFAULT 0.00,
  `credit` decimal(15,2) DEFAULT 0.00,
  `running_balance` decimal(15,2) DEFAULT 0.00,
  `status` enum('in pay','confirmed') DEFAULT 'in pay',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `account_ledger`
--

INSERT INTO `account_ledger` (`id`, `account_id`, `date`, `description`, `reference_type`, `reference_id`, `debit`, `credit`, `running_balance`, `status`, `created_at`) VALUES
(1, 1, '2025-07-06 00:00:00', 'Supplier payment', 'payment', 1, 0.00, 3719.88, -3719.88, 'confirmed', '2025-07-06 15:28:56'),
(2, 1, '2025-07-06 00:00:00', 'Supplier payment', 'payment', 2, 0.00, 300.00, -4019.88, 'confirmed', '2025-07-06 15:29:15'),
(3, 1, '2025-07-06 00:00:00', 'Supplier payment', 'payment', 3, 0.00, 400.00, -4419.88, 'confirmed', '2025-07-06 15:32:42'),
(4, 1, '2025-07-06 00:00:00', 'Supplier payment', 'payment', 4, 0.00, 370.00, -4789.88, 'confirmed', '2025-07-06 15:35:39'),
(5, 1, '2025-07-06 00:00:00', 'Customer payment', 'receipt', 1, 700.70, 0.00, -4789.89, 'confirmed', '2025-07-06 17:05:00'),
(6, 1, '2025-07-06 00:00:00', 'tst', 'expense', 10, 0.00, 1000.00, -5789.89, 'confirmed', '2025-07-06 17:29:04'),
(7, 17, '2025-07-06 00:00:00', 'tst', 'expense', 10, 1000.00, 0.00, 1000.00, 'confirmed', '2025-07-06 17:29:04'),
(10, 23, '2025-07-07 00:00:00', 'bb', 'expense', 15, 0.00, 1000.00, -1000.00, 'confirmed', '2025-07-07 17:29:34'),
(11, 84, '2025-07-07 00:00:00', 'bb', 'expense', 15, 1000.00, 0.00, 1000.00, 'confirmed', '2025-07-07 17:29:34'),
(12, 24, '2025-07-07 00:00:00', '1200', 'expense', 16, 0.00, 1000.00, -1000.00, 'confirmed', '2025-07-07 17:37:34'),
(13, 83, '2025-07-07 00:00:00', '1200', 'expense', 16, 1000.00, 0.00, 1000.00, 'confirmed', '2025-07-07 17:37:34'),
(14, 24, '2025-07-08 00:00:00', 'v', 'expense', 21, 0.00, 100.00, -1100.00, 'confirmed', '2025-07-08 10:11:13'),
(15, 84, '2025-07-08 00:00:00', 'v', 'expense', 21, 100.00, 0.00, 1100.00, 'confirmed', '2025-07-08 10:11:13'),
(16, 32, '2025-07-08 00:00:00', 'Accrued expense', 'expense', 22, 0.00, 200.00, 200.00, 'confirmed', '2025-07-08 10:16:23'),
(17, 81, '2025-07-08 00:00:00', 'Expense', 'expense', 22, 200.00, 0.00, 200.00, 'confirmed', '2025-07-08 10:16:23'),
(18, 32, '2025-07-08 00:00:00', 'Accrued expense', 'expense', 32, 0.00, 200.00, 400.00, 'confirmed', '2025-07-08 15:35:54'),
(19, 81, '2025-07-08 00:00:00', 'Expense', 'expense', 32, 200.00, 0.00, 400.00, 'confirmed', '2025-07-08 15:35:54'),
(20, 23, '2025-07-08 00:00:00', 'Customer payment', 'receipt', 2, 60.50, 0.00, -100060.50, 'confirmed', '2025-07-08 16:05:45'),
(21, 24, '2025-07-12 00:00:00', 'Supplier payment', 'payment', 5, 0.00, 200.00, -1300.00, 'confirmed', '2025-07-12 08:17:26'),
(22, 22, '2025-07-12 00:00:00', 'Customer payment', 'receipt', 3, 8690.00, 0.00, 8690.00, 'confirmed', '2025-07-12 09:28:42'),
(23, 23, '2025-07-12 00:00:00', 'Customer payment', 'receipt', 4, 400.00, 0.00, -100060.54, 'confirmed', '2025-07-12 09:34:26'),
(24, 23, '2025-07-12 00:00:00', 'Customer payment', 'receipt', 5, 300.00, 0.00, -100060.54, 'confirmed', '2025-07-12 09:34:51'),
(25, 23, '2025-07-12 00:00:00', 'Customer payment', 'receipt', 6, 210.00, 0.00, -100060.54, 'confirmed', '2025-07-12 09:40:56'),
(26, 23, '2025-07-12 00:00:00', 'Customer payment', 'receipt', 7, 100.00, 0.00, -100060.54, 'confirmed', '2025-07-12 10:07:34'),
(27, 21, '2025-07-13 00:00:00', 'Customer payment', 'receipt', 8, 400.00, 0.00, 400.00, 'confirmed', '2025-07-13 07:09:46'),
(28, 23, '2025-07-13 00:00:00', 'Customer payment', 'receipt', 9, 40.00, 0.00, -100060.54, 'confirmed', '2025-07-13 07:37:16'),
(29, 23, '2025-07-13 00:00:00', 'Customer payment', 'receipt', 10, 200.00, 0.00, -100020.54, 'confirmed', '2025-07-13 07:48:15'),
(30, 29, '2025-07-13 00:00:00', 'Supplier payment', 'payment', 6, 0.00, 200.00, -200.00, 'confirmed', '2025-07-13 08:12:40'),
(31, 23, '2025-07-13 00:00:00', 'Customer payment', 'receipt', 11, 30.50, 0.00, -100020.54, 'confirmed', '2025-07-13 08:17:40'),
(32, 23, '2025-07-13 00:00:00', 'Customer payment', 'receipt', 12, 35.00, 0.00, -100020.54, 'in pay', '2025-07-13 08:24:37'),
(33, 23, '2025-07-13 00:00:00', 'Supplier payment', 'payment', 7, 0.00, 120.00, -100140.54, 'confirmed', '2025-07-13 08:35:37'),
(34, 23, '2025-07-13 00:00:00', 'Supplier payment', 'payment', 8, 0.00, 200.00, -100340.54, 'confirmed', '2025-07-13 08:41:29'),
(35, 22, '2025-07-16 00:00:00', 'Customer payment', 'receipt', 13, 13200.00, 0.00, 8690.00, 'in pay', '2025-07-16 15:52:50'),
(36, 22, '2025-07-16 00:00:00', 'Customer payment', 'receipt', 14, 148.50, 0.00, 8690.00, 'in pay', '2025-07-16 15:52:51'),
(37, 22, '2025-07-16 00:00:00', 'Customer payment', 'receipt', 15, 99.00, 0.00, 869099.00, 'confirmed', '2025-07-16 15:52:51'),
(38, 23, '2025-07-17 00:00:00', 'Customer payment', 'receipt', 16, 93.50, 0.00, -100340.54, 'in pay', '2025-07-17 11:03:34'),
(39, 23, '2025-07-17 00:00:00', 'Customer payment', 'receipt', 17, 60.50, 0.00, -100340.54, 'in pay', '2025-07-17 11:03:35'),
(40, 32, '2025-07-23 00:00:00', 'test', 'expense', 69, 0.00, 5000.00, 5400.00, 'confirmed', '2025-07-23 15:01:56'),
(41, 110, '2025-07-23 00:00:00', 'test', 'expense', 69, 5000.00, 0.00, 5000.00, 'confirmed', '2025-07-23 15:01:56'),
(42, 23, '2025-07-28 00:00:00', 'desc', 'expense', 71, 0.00, 2000.00, -102340.54, 'confirmed', '2025-07-28 11:18:33'),
(43, 85, '2025-07-28 00:00:00', 'desc', 'expense', 71, 2000.00, 0.00, 2000.00, 'confirmed', '2025-07-28 11:18:33'),
(44, 23, '2025-08-06 00:00:00', 'Customer payment', 'receipt', 18, 2000.00, 0.00, -102340.54, 'confirmed', '2025-08-06 19:31:11'),
(45, 23, '2025-08-06 00:00:00', 'Customer payment RCP-10171-1754513370', 'receipt', 22, 4.00, 0.00, -102340.54, 'confirmed', '2025-08-06 20:50:55'),
(46, 23, '2025-08-07 00:00:00', 'test', 'expense', 93, 0.00, 1000.00, -103340.54, 'confirmed', '2025-08-07 03:28:07'),
(47, 81, '2025-08-07 00:00:00', 'test', 'expense', 93, 1000.00, 0.00, 1400.00, 'confirmed', '2025-08-07 03:28:07'),
(48, 23, '2025-08-09 00:00:00', 'Supplier payment', 'payment', 9, 0.00, 4.00, -103344.54, 'confirmed', '2025-08-09 13:03:12'),
(49, 21, '2025-08-09 00:00:00', 'Supplier payment', 'payment', 10, 0.00, 100.00, 300.00, 'confirmed', '2025-08-09 13:05:46'),
(50, 23, '2025-08-19 00:00:00', 'Customer payment RCP-2221-17555766320', 'receipt', 24, 2000.00, 0.00, -103344.54, 'confirmed', '2025-08-19 04:12:07');

-- --------------------------------------------------------

--
-- Table structure for table `account_types`
--

CREATE TABLE `account_types` (
  `id` int(11) NOT NULL,
  `account_type` varchar(100) NOT NULL,
  `account_category` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `account_types`
--

INSERT INTO `account_types` (`id`, `account_type`, `account_category`, `created_at`) VALUES
(4, 'Fixed Assets', 1, '2025-06-15 12:20:35'),
(5, 'Non-current Assets', 1, '2025-06-15 12:23:45'),
(6, 'Current Assets', 1, '2025-06-15 12:24:10'),
(7, 'Receivable', 1, '2025-06-15 12:25:37'),
(8, 'Prepayment', 1, '2025-06-15 12:26:44'),
(9, 'Bank and Cash', 1, '2025-06-15 12:27:20'),
(10, 'Payable', 2, '2025-06-15 12:28:32'),
(11, 'Current Liabilities', 2, '2025-06-15 12:29:50'),
(12, 'Credit Card', 2, '2025-06-15 12:30:13'),
(13, 'Equity', 3, '2025-06-15 12:30:59'),
(14, 'Income', 4, '2025-06-15 12:31:33'),
(15, 'Cost of Revenue', 5, '2025-06-15 12:32:33'),
(16, 'Expense', 5, '2025-06-15 12:33:02'),
(17, 'Depreciation', 5, '2025-06-15 12:35:11'),
(18, 'Current Year Earnings', 3, '2025-06-15 12:36:17'),
(19, 'Other Income', 4, '2025-06-15 15:04:27');

-- --------------------------------------------------------

--
-- Table structure for table `allowed_ips`
--

CREATE TABLE `allowed_ips` (
  `id` int(11) NOT NULL,
  `ip_address` varchar(45) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `allowed_ips`
--

INSERT INTO `allowed_ips` (`id`, `ip_address`, `description`, `is_active`, `created_at`, `updated_at`) VALUES
(7, '192.168.100.2', 'Main Office Network', 1, '2025-07-19 10:49:16', '2025-07-19 10:54:41'),
(8, '192.168.100.1', 'Office WiFi', 1, '2025-07-19 10:49:16', '2025-07-19 21:10:24'),
(9, '10.0.0.50', 'Branch Office Network', 1, '2025-07-19 10:49:16', '2025-07-19 10:49:16'),
(10, '172.16.0.10', 'Remote Office', 1, '2025-07-19 10:49:16', '2025-07-19 10:49:16'),
(11, '127.0.0.1', 'Local Development', 1, '2025-07-19 10:49:16', '2025-07-19 10:49:16'),
(12, '::1', 'Local Development IPv6', 1, '2025-07-19 10:49:16', '2025-07-19 10:49:16'),
(13, 'unknown', 'Web Platform - IP detection handled by backend', 1, '2025-07-19 10:59:02', '2025-07-19 10:59:02'),
(14, '192.168.100.0/24', 'Main office network - allows all devices (192.168.100.1-254)', 1, '2025-07-19 21:21:46', '2025-07-19 21:21:46'),
(15, '192.168.1.0/24', 'Common home/office network (192.168.1.1-254)', 0, '2025-07-19 21:21:46', '2025-07-19 21:29:43'),
(16, '192.168.0.0/24', 'Alternative office network (192.168.0.1-254)', 0, '2025-07-19 21:21:46', '2025-07-19 21:29:43'),
(17, '10.0.0.0/8', 'Large corporate networks (10.x.x.x)', 0, '2025-07-19 21:21:46', '2025-07-19 21:29:44'),
(18, '172.16.0.0/12', 'Corporate networks (172.16-31.x.x)', 0, '2025-07-19 21:21:46', '2025-07-19 21:29:44');

-- --------------------------------------------------------

--
-- Table structure for table `assets`
--

CREATE TABLE `assets` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `purchase_date` date NOT NULL,
  `purchase_value` decimal(15,2) NOT NULL,
  `description` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `assets`
--

INSERT INTO `assets` (`id`, `account_id`, `name`, `purchase_date`, `purchase_value`, `description`, `created_at`, `updated_at`) VALUES
(1, 5, 'Tables', '2025-07-08', 2000.00, 'nn', '2025-07-07 09:17:24', '2025-07-07 09:17:24'),
(2, 6, 'Tables 2', '2025-07-08', 2000.00, 'bb', '2025-07-08 04:04:53', '2025-07-08 04:04:53'),
(3, 5, 'AN', '2025-07-08', 7000.00, NULL, '2025-07-08 04:20:46', '2025-07-08 04:20:46'),
(4, 6, 'Laptops', '2025-07-08', 50000.00, NULL, '2025-07-08 14:10:25', '2025-07-08 14:10:25'),
(5, 6, 'desks', '2025-07-08', 200000.00, NULL, '2025-07-08 14:11:16', '2025-07-08 14:11:16'),
(6, 6, 'test asset', '2025-07-23', 2000.00, 'test', '2025-07-23 08:49:42', '2025-07-23 08:49:42');

-- --------------------------------------------------------

--
-- Table structure for table `asset_assignments`
--

CREATE TABLE `asset_assignments` (
  `id` int(11) NOT NULL,
  `asset_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `assigned_date` date NOT NULL,
  `assigned_by` int(11) NOT NULL,
  `comment` text DEFAULT NULL,
  `status` enum('active','returned','lost','damaged') DEFAULT 'active',
  `returned_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `asset_assignments`
--

INSERT INTO `asset_assignments` (`id`, `asset_id`, `staff_id`, `assigned_date`, `assigned_by`, `comment`, `status`, `returned_date`, `created_at`, `updated_at`) VALUES
(1, 3, 13, '2025-08-21', 1, 'NNN', 'active', NULL, '2025-08-21 19:41:53', '2025-08-21 19:41:53'),
(2, 2, 1, '2025-08-21', 1, 'test return', 'returned', '2025-08-21', '2025-08-21 19:48:48', '2025-08-21 19:56:45'),
(3, 2, 6, '2025-08-21', 1, 'more', 'returned', '2025-08-21', '2025-08-21 19:57:24', '2025-08-21 19:57:53'),
(4, 4, 9, '2025-08-25', 1, 'return', 'returned', '2025-08-25', '2025-08-25 12:39:27', '2025-08-25 12:39:52');

-- --------------------------------------------------------

--
-- Table structure for table `asset_types`
--

CREATE TABLE `asset_types` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance`
--

CREATE TABLE `attendance` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `checkin_time` datetime DEFAULT NULL,
  `checkout_time` datetime DEFAULT NULL,
  `checkin_latitude` decimal(10,8) DEFAULT NULL,
  `checkin_longitude` decimal(11,8) DEFAULT NULL,
  `checkout_latitude` decimal(10,8) DEFAULT NULL,
  `checkout_longitude` decimal(11,8) DEFAULT NULL,
  `checkin_location` varchar(255) DEFAULT NULL,
  `checkout_location` varchar(255) DEFAULT NULL,
  `checkin_ip` varchar(45) DEFAULT NULL,
  `checkout_ip` varchar(45) DEFAULT NULL,
  `status` int(2) NOT NULL DEFAULT 1,
  `type` enum('regular','overtime','leave') NOT NULL DEFAULT 'regular',
  `total_hours` decimal(5,2) DEFAULT NULL,
  `overtime_hours` decimal(5,2) NOT NULL DEFAULT 0.00,
  `is_late` tinyint(1) NOT NULL DEFAULT 0,
  `late_minutes` int(11) NOT NULL DEFAULT 0,
  `device_info` text DEFAULT NULL,
  `timezone` varchar(50) NOT NULL DEFAULT 'UTC',
  `shift_start` time DEFAULT NULL,
  `shift_end` time DEFAULT NULL,
  `is_early_departure` tinyint(1) NOT NULL DEFAULT 0,
  `early_departure_minutes` int(11) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `attendance`
--

INSERT INTO `attendance` (`id`, `staff_id`, `date`, `checkin_time`, `checkout_time`, `checkin_latitude`, `checkin_longitude`, `checkout_latitude`, `checkout_longitude`, `checkin_location`, `checkout_location`, `checkin_ip`, `checkout_ip`, `status`, `type`, `total_hours`, `overtime_hours`, `is_late`, `late_minutes`, `device_info`, `timezone`, `shift_start`, `shift_end`, `is_early_departure`, `early_departure_minutes`, `notes`, `created_at`, `updated_at`) VALUES
(19, 1, '2025-07-24', '2025-07-24 09:30:12', NULL, -1.21490339, 36.88713536, NULL, NULL, NULL, NULL, '192.168.100.15', NULL, 1, 'regular', NULL, 0.00, 1, 690, NULL, 'UTC', '09:00:00', '17:00:00', 0, 0, NULL, '2025-07-20 15:30:12', '2025-07-24 07:44:53');

-- --------------------------------------------------------

--
-- Table structure for table `Category`
--

CREATE TABLE `Category` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Category`
--

INSERT INTO `Category` (`id`, `name`) VALUES
(1, 'Cheese'),
(3, 'Ghee'),
(4, 'Fresh Milk'),
(5, 'Long Life'),
(8, 'KCC Butter'),
(9, 'Shakes'),
(10, 'Yoghurt'),
(11, 'Mala'),
(12, 'Milk Powder');

-- --------------------------------------------------------

--
-- Table structure for table `CategoryPriceOption`
--

CREATE TABLE `CategoryPriceOption` (
  `id` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `label` varchar(100) NOT NULL,
  `value` decimal(15,2) NOT NULL,
  `value_tzs` decimal(15,2) NOT NULL,
  `value_ngn` decimal(15,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chart_of_accounts`
--

CREATE TABLE `chart_of_accounts` (
  `id` int(11) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `account_code` varchar(20) NOT NULL,
  `account_type` int(11) NOT NULL,
  `parent_account_id` int(11) NOT NULL,
  `description` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_active` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `chart_of_accounts`
--

INSERT INTO `chart_of_accounts` (`id`, `account_name`, `account_code`, `account_type`, `parent_account_id`, `description`, `created_at`, `updated_at`, `is_active`) VALUES
(3, 'Fixtures and Fittings', '003000', 4, 1, '', '2025-06-15 13:19:13', '2025-07-07 18:00:36', 1),
(4, 'Land and Buildings', '004000', 4, 1, '', '2025-06-15 13:20:02', '2025-07-07 18:00:36', 1),
(5, 'Motor Vehicles', '005000', 4, 1, '', '2025-06-15 13:21:08', '2025-07-07 18:00:36', 1),
(6, 'Office equipment (inc computer equipment)\n', '006000', 4, 1, '', '2025-06-15 13:26:32', '2025-07-07 18:00:36', 1),
(7, 'Plant and Machinery', '007000', 4, 1, '', '2025-06-15 13:27:13', '2025-07-07 18:00:36', 1),
(8, 'Intangible Assets -ERP & Sales App', '008000', 5, 1, '', '2025-06-15 13:28:15', '2025-07-07 18:00:36', 1),
(9, 'Biological Assets', '009000', 5, 1, '', '2025-06-15 13:28:54', '2025-07-07 18:00:36', 1),
(10, 'Stock', '100001', 6, 1, '', '2025-06-15 13:30:13', '2025-07-07 18:00:36', 1),
(11, 'Stock Interim (Received)', '100002', 6, 1, '', '2025-06-15 13:30:59', '2025-07-07 18:00:36', 1),
(12, 'Debtors Control Account', '110000', 7, 1, ' | Last invoice: INV-3-1751913238102 | Last invoice: INV-2-1751918138904 | Last invoice: INV-3-1751996124894 | Last invoice: INV-2-1752309325399 | Last invoice: INV-2-1752320810962', '2025-06-15 13:32:13', '2025-07-07 18:00:36', 1),
(13, 'Debtors Control Account (POS)', '110001', 7, 1, '', '2025-06-15 13:33:00', '2025-07-07 18:00:36', 1),
(14, 'Other debtors', '110002', 7, 1, '', '2025-06-15 14:39:31', '2025-07-07 18:00:36', 1),
(15, 'Prepayments', '110003', 8, 1, '', '2025-06-15 14:40:01', '2025-07-07 18:00:36', 1),
(16, 'Purchase Tax Control Account', '110004', 6, 1, '', '2025-06-15 14:41:11', '2025-07-07 18:00:36', 1),
(17, 'WithHolding Tax Advance on', '110005', 6, 1, '', '2025-06-15 14:41:56', '2025-07-07 18:00:36', 1),
(18, 'Bank Suspense Account', '110006', 6, 1, '', '2025-06-15 14:42:24', '2025-07-07 18:00:36', 1),
(19, 'Outstanding Receipts', '110007', 7, 1, '', '2025-06-15 14:42:57', '2025-07-07 18:00:36', 1),
(20, 'Outstanding Payments', '110008', 6, 1, '', '2025-06-15 14:43:27', '2025-07-07 18:00:36', 1),
(21, 'DTB KES', '120001', 9, 1, '', '2025-06-15 14:44:02', '2025-07-07 18:00:36', 1),
(22, 'DTB USD', '120002', 9, 1, '', '2025-06-15 14:44:41', '2025-07-07 18:00:36', 1),
(23, 'M-pesa', '120003', 9, 1, '', '2025-06-15 14:45:07', '2025-07-07 18:00:36', 1),
(24, 'Cash', '120004', 9, 1, '', '2025-06-15 14:45:26', '2025-07-07 18:00:36', 1),
(25, 'DTB-PICTURES PAYMENTS', '120005', 9, 1, '', '2025-06-15 14:46:11', '2025-07-07 18:00:36', 1),
(26, 'ABSA', '120006', 9, 1, '', '2025-06-15 14:46:42', '2025-07-07 18:00:36', 1),
(27, 'SANLAM MMF-USD', '120007', 9, 1, '', '2025-06-15 14:47:26', '2025-07-07 18:00:36', 1),
(28, 'ABSA-USD', '120008', 9, 1, '', '2025-06-15 14:47:49', '2025-07-07 18:00:36', 1),
(29, 'ECO BANK KES', '120009', 9, 1, '', '2025-06-15 14:48:23', '2025-07-07 18:00:36', 1),
(30, 'Accounts Payables', '210000', 10, 2, '', '2025-06-15 14:50:18', '2025-07-07 18:00:36', 1),
(31, 'Other Creditors', '210002', 11, 2, '', '2025-06-15 14:50:56', '2025-07-07 18:00:36', 1),
(32, 'Accrued Liabilities', '210003', 11, 2, '', '2025-06-15 14:51:26', '2025-07-07 18:00:36', 1),
(33, 'Company Credit Card', '210004', 12, 2, '', '2025-06-15 14:51:55', '2025-07-07 18:00:36', 1),
(34, 'Bad debt provision', '210005', 11, 2, '', '2025-06-15 14:52:40', '2025-07-07 18:00:36', 1),
(35, 'Sales Tax Control Account', '210006', 11, 2, '', '2025-06-15 14:53:12', '2025-07-07 18:00:36', 1),
(36, 'Withholding Tax Payable', '210007', 11, 2, '', '2025-06-15 14:53:51', '2025-07-07 18:00:36', 1),
(37, 'PAYE', '210008', 10, 2, '', '2025-06-15 14:54:27', '2025-07-07 18:00:36', 1),
(38, 'Net Wages', '210009', 10, 2, '', '2025-06-15 14:55:05', '2025-07-07 18:00:36', 1),
(39, 'NSSF', '210010', 10, 2, '', '2025-06-15 14:55:32', '2025-07-07 18:00:36', 1),
(40, 'NHIF', '210011', 10, 2, '', '2025-06-15 14:56:11', '2025-07-07 18:00:36', 1),
(41, 'AHL', '210012', 10, 2, '', '2025-06-15 14:56:42', '2025-07-07 18:00:36', 1),
(42, 'Due To and From Directors', '210013', 11, 2, '', '2025-06-15 14:57:16', '2025-07-07 18:00:36', 1),
(43, 'Due To and From Related Party- MSP', '210014', 11, 2, '', '2025-06-15 14:57:46', '2025-07-07 18:00:36', 1),
(44, 'Due To Other Parties', '210015', 11, 2, '', '2025-06-15 14:58:11', '2025-07-07 18:00:36', 1),
(45, 'Corporation Tax', '210016', 10, 2, '', '2025-06-15 14:58:35', '2025-07-07 18:00:36', 1),
(46, 'Wage After Tax: Accrued Liabilities', '210022', 10, 2, '', '2025-06-15 14:58:59', '2025-07-07 18:00:36', 1),
(47, 'Due To and From Related Party- GQ', '210024', 11, 2, '', '2025-06-15 14:59:52', '2025-07-07 18:00:36', 1),
(48, 'Due To and From Woosh Intl- TZ', '210034', 11, 2, '', '2025-06-15 15:00:20', '2025-07-07 18:00:36', 1),
(49, 'Share Capital', '300001', 13, 3, '', '2025-06-15 15:00:43', '2025-07-07 18:00:36', 1),
(50, 'Retained Earnings', '300002', 13, 3, '', '2025-06-15 15:01:19', '2025-07-07 18:00:36', 1),
(51, 'Other reserves', '300003', 13, 3, '', '2025-06-15 15:01:39', '2025-07-07 18:00:36', 1),
(52, 'Capital', '300004', 13, 3, '', '2025-06-15 15:01:59', '2025-07-07 18:00:36', 1),
(53, 'Sales Revenue', '400001', 14, 4, '', '2025-06-15 15:02:21', '2025-07-07 18:00:36', 1),
(54, 'GOLD PUFF SALES', '400002', 14, 4, '', '2025-06-15 15:02:50', '2025-07-07 18:00:36', 1),
(55, 'WILD LUCY SALES', '400003', 14, 4, '', '2025-06-15 15:03:15', '2025-07-07 18:00:36', 1),
(56, 'Cash Discount Gain', '400004', 19, 0, '', '2025-06-15 15:04:54', '2025-07-07 18:00:36', 1),
(57, 'Profits/Losses on disposals of assets', '400005', 14, 4, '', '2025-06-15 15:05:26', '2025-07-07 18:00:36', 1),
(58, 'Other Income', '400006', 19, 0, '', '2025-06-15 15:05:48', '2025-07-07 18:00:36', 1),
(59, 'GOLD PUFF RECHARGEABLE SALES', '400007', 14, 4, '', '2025-06-15 15:06:13', '2025-07-07 18:00:36', 1),
(60, 'GOLD POUCH 5 DOT SALES', '400008', 14, 4, '', '2025-06-15 15:06:37', '2025-07-07 18:00:36', 1),
(61, 'GOLD POUCH 3 DOT SALES', '400009', 14, 4, '', '2025-06-15 15:07:14', '2025-07-07 18:00:36', 1),
(62, 'GOLD PUFF 3000 PUFFS RECHARGEABLE SALES', '400010', 14, 4, '', '2025-06-15 15:07:39', '2025-07-07 18:00:36', 1),
(63, 'Cost of sales 1', '500000', 15, 5, '', '2025-06-15 15:08:06', '2025-07-07 18:00:36', 1),
(64, 'Cost of sales 2', '500001', 15, 5, '', '2025-06-15 15:08:26', '2025-07-07 18:00:36', 1),
(65, 'GOLD PUFF COST OF SALES', '500002', 15, 5, '', '2025-06-15 15:08:53', '2025-07-07 18:00:36', 1),
(66, 'WILD LUCY COST OF SALES', '500003', 15, 5, '', '2025-06-15 15:09:13', '2025-07-07 18:00:36', 1),
(67, 'Other costs of sales - Vapes Write Offs', '500004', 15, 5, '', '2025-06-15 15:09:36', '2025-07-07 18:00:36', 1),
(68, 'Other costs of sales', '500005', 15, 5, '', '2025-06-15 15:09:59', '2025-07-07 18:00:36', 1),
(69, 'Freight and delivery - COS E-Cigarette', '500006', 15, 5, '', '2025-06-15 15:10:25', '2025-07-07 18:00:36', 1),
(70, 'Discounts given - COS', '500007', 15, 5, '', '2025-06-15 15:10:45', '2025-07-07 18:00:36', 1),
(71, 'Direct labour - COS', '500008', 15, 5, '', '2025-06-15 15:11:07', '2025-07-07 18:00:36', 1),
(72, 'Commissions and fees', '500009', 15, 5, '', '2025-06-15 15:11:30', '2025-07-07 18:00:36', 1),
(73, 'Bar Codes/ Stickers', '500010', 15, 5, '', '2025-06-15 15:12:01', '2025-07-07 18:00:36', 1),
(74, 'GOLD PUFF RECHARGEABLE COST OF SALES', '500011', 15, 5, '', '2025-06-15 15:12:35', '2025-07-07 18:00:36', 1),
(75, 'Rebates,Price Diff & Discounts', '500012', 15, 5, '', '2025-06-15 15:12:55', '2025-07-07 18:00:36', 1),
(76, 'GOLD POUCH 5 DOT COST OF SALES', '500013', 15, 5, '', '2025-06-15 15:13:17', '2025-07-07 18:00:36', 1),
(77, 'GOLD POUCH 3 DOT COST OF SALES', '500014', 15, 5, '', '2025-06-15 15:13:38', '2025-07-07 18:00:36', 1),
(78, 'GOLD PUFF 3000 PUFFS RECHARGEABLE COST OF SALES', '500015', 15, 5, '', '2025-06-15 15:14:02', '2025-07-07 18:00:36', 1),
(79, 'Vehicle Washing', '510001', 16, 5, '', '2025-06-15 15:31:22', '2025-07-07 18:00:36', 1),
(80, 'Vehicle R&M', '510002', 16, 5, '', '2025-06-15 15:31:49', '2025-07-07 18:00:36', 1),
(81, 'Vehicle Parking Fee', '510003', 16, 5, '', '2025-06-15 15:32:15', '2025-07-07 18:00:36', 1),
(82, 'Vehicle Insurance fee', '510004', 16, 5, '', '2025-06-15 15:32:47', '2025-07-07 18:00:36', 1),
(83, 'Vehicle fuel cost', '510005', 16, 5, '', '2025-06-15 15:33:09', '2025-07-07 18:00:36', 1),
(84, 'Driver Services', '510006', 16, 5, '', '2025-06-15 15:33:35', '2025-07-07 18:00:36', 1),
(85, 'Travel expenses - selling expenses', '510007', 16, 5, '', '2025-06-15 15:34:04', '2025-07-07 18:00:36', 1),
(86, 'Travel expenses - Sales Fuel Allowance', '510008', 16, 5, '', '2025-06-15 15:34:30', '2025-07-07 18:00:36', 1),
(87, 'Travel expenses - Sales Car Lease', '510009', 16, 5, '', '2025-06-15 15:35:05', '2025-07-07 18:00:36', 1),
(88, 'Travel expenses - Other Travel Expenses', '510010', 16, 5, '', '2025-06-15 15:35:55', '2025-07-07 18:00:36', 1),
(89, 'Travel expenses- General Fuel Allowance', '510011', 16, 5, '', '2025-06-15 15:36:51', '2025-07-07 18:00:36', 1),
(90, 'Travel expenses - General Car Lease', '510012', 16, 5, '', '2025-06-15 15:37:20', '2025-07-07 18:00:36', 1),
(91, 'Travel Expense- General and admin expenses', '510013', 16, 5, '', '2025-06-15 15:37:46', '2025-07-07 18:00:36', 1),
(92, 'Mpesa handling fee', '510014', 16, 5, '', '2025-06-15 15:38:09', '2025-07-07 18:00:36', 1),
(93, 'Other Types of Expenses-Advertising Expenses', '510015', 16, 5, '', '2025-06-15 15:38:34', '2025-07-07 18:00:36', 1),
(94, 'Merchandize', '510016', 16, 5, '', '2025-06-15 15:38:58', '2025-07-07 18:00:36', 1),
(95, 'Influencer Payment', '510017', 16, 5, '', '2025-06-15 15:39:20', '2025-07-07 18:00:36', 1),
(96, 'Advertizing Online', '510018', 16, 5, '', '2025-06-15 15:39:41', '2025-07-07 18:00:36', 1),
(97, 'Trade Marketing Costs', '510019', 16, 5, '', '2025-06-15 15:40:05', '2025-07-07 18:00:36', 1),
(98, 'Activation', '510020', 16, 5, '', '2025-06-15 15:40:25', '2025-07-07 18:00:36', 1),
(99, 'Other selling expenses', '510021', 16, 5, '', '2025-06-15 15:40:47', '2025-07-07 18:00:36', 1),
(100, 'Other general and administrative expenses', '510022', 16, 5, '', '2025-06-15 15:41:08', '2025-07-07 18:00:36', 1),
(101, 'Rent or Lease of Apartments', '510023', 16, 5, '', '2025-06-15 15:41:30', '2025-07-07 18:00:36', 1),
(102, 'Penalty & Interest Account', '510024', 16, 5, '', '2025-06-15 15:41:58', '2025-07-07 18:00:36', 1),
(103, 'Dues and subscriptions', '510025', 16, 5, '', '2025-06-15 15:42:19', '2025-07-07 18:00:36', 1),
(104, 'Utilities (Electricity and Water)', '510026', 16, 5, '', '2025-06-15 15:42:43', '2025-07-07 18:00:36', 1),
(105, 'Telephone and postage', '510027', 16, 5, '', '2025-06-15 15:43:13', '2025-07-07 18:00:36', 1),
(106, 'Stationery and printing', '510028', 16, 5, '', '2025-06-15 15:43:33', '2025-07-07 18:00:36', 1),
(107, 'Service Fee', '510029', 16, 5, '', '2025-06-15 15:43:54', '2025-07-07 18:00:36', 1),
(108, 'Repairs and Maintenance', '510030', 16, 5, '', '2025-06-15 15:44:15', '2025-07-07 18:00:36', 1),
(109, 'Rent or lease payments', '510031', 16, 5, '', '2025-06-15 15:44:45', '2025-07-07 18:00:36', 1),
(110, 'Office Internet', '510032', 16, 5, '', '2025-06-15 15:45:05', '2025-07-07 18:00:36', 1),
(111, 'Office decoration Expense', '510033', 16, 5, '', '2025-06-15 15:45:26', '2025-07-07 18:00:36', 1),
(112, 'Office Cleaning and Sanitation', '510034', 16, 5, '', '2025-06-15 15:45:51', '2025-07-07 18:00:36', 1),
(113, 'IT Development', '510035', 16, 5, '', '2025-06-15 15:46:12', '2025-07-07 18:00:36', 1),
(114, 'Insurance - Liability', '510036', 16, 5, '', '2025-06-15 15:46:34', '2025-07-07 18:00:36', 1),
(115, 'Business license fee', '510037', 16, 5, '', '2025-06-15 15:46:58', '2025-07-07 18:00:36', 1),
(116, 'Other Legal and Professional Fees', '510038', 16, 5, '', '2025-06-15 15:47:31', '2025-07-07 18:00:36', 1),
(117, 'IT Expenses', '510039', 16, 5, '', '2025-06-15 15:47:51', '2025-07-07 18:00:36', 1),
(118, 'Recruitment fee', '510040', 16, 5, '', '2025-06-15 15:48:18', '2025-07-07 18:00:36', 1),
(119, 'Payroll Expenses(Before Tax)', '510041', 16, 5, '', '2025-06-15 15:48:44', '2025-07-07 18:00:36', 1),
(120, 'Outsourced Labor Services', '510042', 16, 5, '', '2025-06-15 15:49:07', '2025-07-07 18:00:36', 1),
(121, 'NSSF ( Company Paid)', '510043', 16, 5, '', '2025-06-15 15:49:34', '2025-07-07 18:00:36', 1),
(122, 'Employee welfare', '510044', 16, 5, '', '2025-06-15 15:49:56', '2025-07-07 18:00:36', 1),
(123, 'Bonus & Allowance', '510045', 16, 5, '', '2025-06-15 15:50:19', '2025-07-07 18:00:36', 1),
(124, 'Affordable Housing Levy (AHL)', '510046', 16, 5, '', '2025-06-15 15:50:43', '2025-07-07 18:00:36', 1),
(125, 'Income tax expense', '510047', 16, 5, '', '2025-06-15 15:51:05', '2025-07-07 18:00:36', 1),
(126, 'Team Building', '510048', 16, 5, '', '2025-06-15 15:51:28', '2025-07-07 18:00:36', 1),
(127, 'Meetings', '510049', 16, 5, '', '2025-06-15 15:51:55', '2025-07-07 18:00:36', 1),
(128, 'Meals and entertainment', '510050', 16, 5, '', '2025-06-15 15:52:20', '2025-07-07 18:00:36', 1),
(129, 'Interest expense', '510051', 16, 5, '', '2025-06-15 15:52:40', '2025-07-07 18:00:36', 1),
(130, 'Bad debts', '510052', 17, 0, '', '2025-06-15 15:53:05', '2025-07-07 18:00:36', 1),
(131, 'Bank handling fee', '510054', 16, 5, '', '2025-06-15 15:53:29', '2025-07-07 18:00:36', 1),
(132, 'Patents & Trademarks Depreciation', '520001', 17, 0, '', '2025-06-15 15:54:02', '2025-07-07 18:00:36', 1),
(133, 'Fixtures and fittings Depreciation', '520002', 16, 5, '', '2025-06-15 15:54:23', '2025-07-07 18:00:36', 1),
(134, 'Land and buildings Depreciation', '520003', 17, 0, '', '2025-06-15 15:54:45', '2025-07-07 18:00:36', 1),
(135, 'Motor vehicles Depreciation', '520004', 17, 0, '', '2025-06-15 15:55:09', '2025-07-07 18:00:36', 1),
(136, 'Office equipment (inc computer equipment) Depreciation', '520005', 17, 0, '', '2025-06-15 15:55:35', '2025-07-07 18:00:36', 1),
(137, 'Plant and machinery Depreciation', '520006', 17, 0, '', '2025-06-15 15:55:58', '2025-07-07 18:00:36', 1),
(138, 'Undistributed Profits/Losses', '999999', 18, 3, '', '2025-06-15 15:56:19', '2025-07-07 18:00:36', 1),
(139, 'Accumulated Depreciation', '520007', 17, 0, NULL, '2025-07-08 06:19:04', '2025-07-08 06:19:04', 1),
(140, 'Accounts Receivable', '1100', 2, 0, 'Amounts owed by customers for goods or services provided | Last invoice: INV-2-1752321159077 | Last invoice: INV-2-1752397570019 | Last invoice: INV-2-1752649457669', '2025-07-12 09:40:18', '2025-07-12 09:40:18', 1),
(141, 'PAYE Payable', '37', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(142, 'Net Wages', '38', 5, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(143, 'NSSF Payable', '39', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(144, 'NHIF Payable', '40', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1);

-- --------------------------------------------------------

--
-- Table structure for table `chart_of_accounts1`
--

CREATE TABLE `chart_of_accounts1` (
  `id` int(11) NOT NULL,
  `account_code` varchar(20) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `account_type` enum('asset','liability','equity','revenue','expense') NOT NULL,
  `parent_account_id` int(11) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `chart_of_accounts1`
--

INSERT INTO `chart_of_accounts1` (`id`, `account_code`, `account_name`, `account_type`, `parent_account_id`, `description`, `is_active`, `created_at`, `updated_at`) VALUES
(1, '1000', 'Cash', 'asset', NULL, 'Cash on hand and in bank', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(2, '1100', 'Accounts Receivable', 'asset', NULL, 'Amounts owed by customers | Last invoice: INV-2-1751827297786 | Last invoice: INV-2-1751827373685 | Last invoice: INV-2-1751828152710', 1, '2025-07-06 07:58:31', '2025-07-06 16:55:53'),
(3, '1200', 'Inventory', 'asset', NULL, 'Merchandise inventory', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(4, '1300', 'Prepaid Expenses', 'asset', NULL, 'Prepaid insurance, rent, etc.', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(5, '1400', 'Fixed Assets', 'asset', NULL, 'Equipment, furniture, vehicles', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(6, '1500', 'Accumulated Depreciation', 'asset', NULL, 'Accumulated depreciation on fixed assets', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(7, '2000', 'Accounts Payable', 'liability', NULL, 'Amounts owed to suppliers | Last PO received: PO-000004 | Last PO received: PO-000005', 1, '2025-07-06 07:58:31', '2025-07-06 15:05:27'),
(8, '2100', 'Accrued Expenses', 'liability', NULL, 'Accrued wages, taxes, etc.', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(9, '2200', 'Notes Payable', 'liability', NULL, 'Bank loans and notes', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(10, '2300', 'Sales Tax Payable', 'liability', NULL, 'Sales tax collected', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(11, '3000', 'Owner\'s Equity', 'equity', NULL, 'Owner\'s investment', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(12, '3100', 'Retained Earnings', 'equity', NULL, 'Accumulated profits', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(13, '3200', 'Owner\'s Draw', 'equity', NULL, 'Owner\'s withdrawals', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(14, '4000', 'Sales Revenue', 'revenue', NULL, 'Revenue from sales', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(15, '4100', 'Other Income', 'revenue', NULL, 'Interest, rent, etc.', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(16, '5000', 'Cost of Goods Sold', 'expense', NULL, 'Cost of merchandise sold', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(17, '5100', 'Advertising Expense', 'expense', NULL, 'Marketing and advertising costs', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(18, '5200', 'Rent Expense', 'expense', NULL, 'Store and office rent', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(19, '5300', 'Utilities Expense', 'expense', NULL, 'Electricity, water, internet', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(20, '5400', 'Wages Expense', 'expense', NULL, 'Employee salaries and wages', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(21, '5500', 'Insurance Expense', 'expense', NULL, 'Business insurance', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(22, '5600', 'Office Supplies', 'expense', NULL, 'Office and store supplies', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(23, '5700', 'Depreciation Expense', 'expense', NULL, 'Depreciation on fixed assets', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31'),
(24, '5800', 'Miscellaneous Expense', 'expense', NULL, 'Other business expenses', 1, '2025-07-06 07:58:31', '2025-07-06 07:58:31');

-- --------------------------------------------------------

--
-- Table structure for table `chat_messages`
--

CREATE TABLE `chat_messages` (
  `id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `message` text NOT NULL,
  `sent_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `chat_messages`
--

INSERT INTO `chat_messages` (`id`, `room_id`, `sender_id`, `message`, `sent_at`) VALUES
(2, 1, 2, 'testing this', '2025-07-10 11:12:48'),
(3, 1, 2, 'testing this here there', '2025-07-10 11:12:48'),
(4, 1, 3, 'testing this', '2025-07-10 11:12:48'),
(5, 1, 2, 'test 23gggj', '2025-07-10 11:30:09'),
(6, 2, 2, 'new group', '2025-07-10 11:31:37'),
(7, 2, 2, 'test 2', '2025-07-10 11:57:34'),
(8, 2, 2, 'bbnnn', '2025-07-10 12:01:21'),
(9, 2, 2, 'nn', '2025-07-10 12:02:42'),
(10, 1, 2, 'bb', '2025-07-10 12:06:43'),
(11, 1, 2, 'ddd', '2025-07-10 12:08:19'),
(12, 1, 2, 'ddd', '2025-07-10 12:08:19'),
(13, 1, 2, 'berr', '2025-07-10 12:08:24'),
(14, 1, 2, 'berr', '2025-07-10 12:08:24'),
(15, 2, 2, 'newest notice', '2025-07-10 12:08:46'),
(16, 2, 2, 'newest', '2025-07-10 12:08:46'),
(17, 2, 2, 'testing', '2025-07-19 13:45:21'),
(18, 2, 2, 'testing', '2025-07-19 13:45:21'),
(19, 3, 1, 'message to every one', '2025-07-23 14:45:59'),
(20, 3, 1, 'message to every one', '2025-07-23 14:45:59'),
(22, 3, 1, 'message to every one', '2025-07-23 14:46:00'),
(23, 5, 6, 'test', '2025-07-28 09:34:29'),
(24, 5, 6, 'test', '2025-07-28 09:34:29'),
(25, 5, 9, 'hi', '2025-08-02 10:15:04'),
(26, 6, 1, 'new message', '2025-08-19 07:13:23'),
(27, 6, 1, 'new message', '2025-08-19 07:13:23'),
(28, 7, 6, 'hi', '2025-08-19 09:53:01'),
(29, 7, 6, 'hi', '2025-08-19 09:53:23'),
(32, 8, 14, 'hi', '2025-08-19 10:43:33'),
(36, 11, 3, 'mmm', '2025-08-19 10:46:00'),
(37, 11, 3, 'mmm', '2025-08-19 10:46:00'),
(40, 1, 3, 'test', '2025-08-19 10:47:46'),
(41, 1, 3, 'test', '2025-08-19 10:47:46'),
(43, 16, 3, 'ddd', '2025-08-19 19:11:25'),
(44, 16, 3, 'ccc', '2025-08-19 19:14:22'),
(45, 16, 3, 'ccc', '2025-08-19 19:14:22'),
(46, 16, 3, 'ffgg', '2025-08-19 19:17:00'),
(47, 16, 3, 'ffgg', '2025-08-19 19:17:00'),
(48, 16, 3, 'c', '2025-08-19 19:18:52'),
(49, 17, 3, 'test', '2025-08-19 19:21:20'),
(50, 17, 1, 'vipi', '2025-08-19 19:21:33'),
(51, 17, 3, 'desrrtt', '2025-08-19 19:21:41'),
(52, 17, 1, 'yyyy', '2025-08-19 19:22:16'),
(53, 17, 3, 'test', '2025-08-19 19:38:30'),
(54, 17, 3, 'test', '2025-08-19 19:38:30'),
(55, 17, 1, 'ty', '2025-08-19 19:39:00'),
(56, 17, 1, 'you', '2025-08-19 19:40:30'),
(57, 17, 3, 'here', '2025-08-19 19:42:43'),
(59, 17, 1, 'tet', '2025-08-19 19:43:22');

-- --------------------------------------------------------

--
-- Table structure for table `chat_rooms`
--

CREATE TABLE `chat_rooms` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `is_group` tinyint(1) DEFAULT 0,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `chat_rooms`
--

INSERT INTO `chat_rooms` (`id`, `name`, `is_group`, `created_by`, `created_at`) VALUES
(1, 'tets', 1, 2, '2025-07-10 11:12:31'),
(2, 'group2', 1, 2, '2025-07-10 11:31:26'),
(3, 'new group', 1, 1, '2025-07-23 14:45:42'),
(4, 'Group 1', 1, 6, '2025-07-24 08:16:43'),
(5, 'payroll', 1, 6, '2025-07-28 09:34:22'),
(6, 'test group', 1, 1, '2025-08-19 07:13:12'),
(7, 'TEST', 1, 6, '2025-08-19 09:52:41'),
(9, '321', 1, 2, '2025-08-19 10:44:12'),
(10, '123', 1, 14, '2025-08-19 10:45:02'),
(11, 'test', 1, 3, '2025-08-19 10:45:53'),
(14, 'test 1', 1, 3, '2025-08-19 10:52:04'),
(15, 'internal', 1, 6, '2025-08-19 11:45:34'),
(16, 'fd', 1, 3, '2025-08-19 19:11:16'),
(17, 'newest', 1, 3, '2025-08-19 19:19:41');

-- --------------------------------------------------------

--
-- Table structure for table `chat_room_members`
--

CREATE TABLE `chat_room_members` (
  `id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `chat_room_members`
--

INSERT INTO `chat_room_members` (`id`, `room_id`, `staff_id`, `joined_at`) VALUES
(1, 1, 2, '2025-07-10 11:12:31'),
(2, 1, 3, '2025-07-10 11:12:31'),
(3, 2, 2, '2025-07-10 11:31:27'),
(4, 2, 3, '2025-07-10 11:31:27'),
(5, 3, 1, '2025-07-23 14:45:42'),
(6, 3, 9, '2025-07-23 14:45:42'),
(7, 3, 2, '2025-07-23 14:45:42'),
(8, 3, 3, '2025-07-23 14:45:42'),
(9, 4, 6, '2025-07-24 08:16:43'),
(10, 4, 9, '2025-07-24 08:16:43'),
(11, 4, 1, '2025-07-24 08:16:43'),
(12, 4, 8, '2025-07-24 08:16:43'),
(13, 4, 3, '2025-07-24 08:16:43'),
(14, 5, 9, '2025-07-28 09:34:23'),
(15, 5, 6, '2025-07-28 09:34:23'),
(16, 5, 7, '2025-07-28 09:34:23'),
(17, 5, 8, '2025-07-28 09:34:23'),
(18, 6, 1, '2025-08-19 07:13:12'),
(19, 6, 13, '2025-08-19 07:13:12'),
(20, 6, 12, '2025-08-19 07:13:12'),
(21, 6, 14, '2025-08-19 07:13:12'),
(22, 6, 11, '2025-08-19 07:13:12'),
(23, 7, 6, '2025-08-19 09:52:42'),
(24, 7, 8, '2025-08-19 09:52:42'),
(25, 8, 2, '2025-08-19 10:43:03'),
(27, 9, 2, '2025-08-19 10:44:12'),
(29, 10, 14, '2025-08-19 10:45:03'),
(31, 11, 14, '2025-08-19 10:45:53'),
(32, 11, 9, '2025-08-19 10:45:53'),
(33, 11, 3, '2025-08-19 10:45:53'),
(34, 12, 11, '2025-08-19 10:45:56'),
(36, 13, 3, '2025-08-19 10:48:16'),
(37, 13, 14, '2025-08-19 10:48:16'),
(39, 14, 14, '2025-08-19 10:52:04'),
(40, 14, 3, '2025-08-19 10:52:04'),
(41, 15, 6, '2025-08-19 11:45:34'),
(42, 15, 8, '2025-08-19 11:45:34'),
(43, 15, 3, '2025-08-19 11:45:34'),
(44, 16, 3, '2025-08-19 19:11:17'),
(45, 16, 2, '2025-08-19 19:11:17'),
(46, 17, 3, '2025-08-19 19:19:41'),
(47, 17, 1, '2025-08-19 19:19:41');

-- --------------------------------------------------------

--
-- Table structure for table `ClientAssignment`
--

CREATE TABLE `ClientAssignment` (
  `id` int(11) NOT NULL,
  `outletId` int(11) NOT NULL,
  `salesRepId` int(11) NOT NULL,
  `assignedAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `status` varchar(191) NOT NULL DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `ClientAssignment`
--

INSERT INTO `ClientAssignment` (`id`, `outletId`, `salesRepId`, `assignedAt`, `status`) VALUES
(1, 10576, 94, '2025-08-25 14:03:27.260', 'active'),
(3, 10577, 94, '2025-08-25 16:16:53.036', 'active');

-- --------------------------------------------------------

--
-- Table structure for table `Clients`
--

CREATE TABLE `Clients` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `address` varchar(191) DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `balance` decimal(11,2) DEFAULT NULL,
  `email` varchar(191) DEFAULT NULL,
  `region_id` int(11) NOT NULL,
  `region` varchar(191) NOT NULL,
  `route_id` int(11) DEFAULT NULL,
  `route_name` varchar(191) DEFAULT NULL,
  `route_id_update` int(11) DEFAULT NULL,
  `route_name_update` varchar(100) DEFAULT NULL,
  `contact` varchar(191) NOT NULL,
  `tax_pin` varchar(191) DEFAULT NULL,
  `location` varchar(191) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `client_type` int(11) DEFAULT NULL,
  `outlet_account` int(11) DEFAULT NULL,
  `payment_terms` int(11) NOT NULL,
  `credit_limit` decimal(11,2) NOT NULL,
  `countryId` int(11) NOT NULL,
  `added_by` int(11) DEFAULT NULL,
  `created_at` datetime(3) DEFAULT current_timestamp(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Clients`
--

INSERT INTO `Clients` (`id`, `name`, `address`, `latitude`, `longitude`, `balance`, `email`, `region_id`, `region`, `route_id`, `route_name`, `route_id_update`, `route_name_update`, `contact`, `tax_pin`, `location`, `status`, `client_type`, `outlet_account`, `payment_terms`, `credit_limit`, `countryId`, `added_by`, `created_at`) VALUES
(10604, 'Naivas Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10605, 'Quickmart Express Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10606, 'Quickmart Main Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10607, 'Magunas Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10608, 'Ottomatt Githunguri/Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10609, 'Weacon Githunguri/Utawala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Utawala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10610, 'Quickmart Embakasi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Embakasi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10611, 'Naivas Nyayo Embakasi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Embakasi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10612, 'Muhindi Mweusi Express', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Express', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10613, 'Muhindi Mweusi Transami', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Transami', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10614, 'Waeconmatt Makuti', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Makuti', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10615, 'Quickmart Pipeline', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Pipeline', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10616, 'Quickmart Outering', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10617, 'Naivas Tassia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tassia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10618, 'Muhindi Mweusi chapchap', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10619, 'Muhindi Mweusi Pipeline', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Pipeline', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10620, 'Quickmart Fedha', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Fedha', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10621, 'Quickmart Donholm', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Donholm', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10622, 'Muhindi Mweusi Tassia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tassia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10623, 'Waeconmatt Fedha', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Fedha', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10624, 'Waeconmatt Tassia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tassia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10625, 'Quickmart Buruburu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Buruburu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10626, 'Naivas T-square', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Buruburu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10627, 'Dimples Umoja', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Umoja', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10628, 'Muhindi Mweusi Umoja', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Umoja', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10629, 'Skymart Umoja Market', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Umoja', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10630, 'Naivas Greenspan', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Greenspan', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10631, 'Cleanshelf Shujaa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Shujaa', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10632, 'Naivas Eastgate', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Eastgate', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10633, 'Skymart Kayole', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kayole', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10634, 'Muhindi Mweusi Kayole Soweto', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10635, 'Naivas Komarock', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Komarock', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10636, 'Cleanshelf Kmall', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kmall', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10637, 'Naivas Saika', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Saika', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10638, 'Muhindi Mweusi -Junction', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Junction', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10639, 'Magunas kayo junction', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10640, 'Naivas Umoja', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Umoja', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10641, 'Quickmart Outering 2', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10642, 'Skymart Umoja 2', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10643, 'Skymart Tena', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Tena', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10644, 'Skymart Moi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Moi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10645, 'Quickmart Ruai', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ruai', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10646, 'Weacon Kamulu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kamulu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10647, 'Otomatt Mutalia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Mutalia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10648, 'Eastmatt Tala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Tala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10649, 'Fastmatt Mtaani', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mtaani', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10650, 'Skymart Tala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10651, 'Fastmatt Kipawa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kipawa', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10652, 'Fastmatt Tala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10653, 'Carrefour Eastleigh', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Eastleigh', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10654, 'Naivas Buruburu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Buruburu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10655, 'Naivas jogoo road', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10656, 'Magunas jogoo road', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10657, 'Naivas Ruai', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ruai', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10658, 'Ottomatt Mutalia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mutalia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10659, 'Waeconmatt kingori', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'kingori', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10660, 'Waeconmatt Joska', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Joska', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10661, 'Waeconmatt malaa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'malaa', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10662, 'Muhindi Mweusi chokaa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10663, 'Quickmart joska', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'joska', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10664, 'Naivas Super Centre', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Centre', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10665, 'Naivas Old Machakos', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Machakos', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10666, 'Quickmart Kitui', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kitui', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10667, 'Naivas kitui', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'kitui', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10668, 'Magunas Kitui', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kitui', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10669, 'Naivas Capital Centre', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mombasa Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10670, 'Naivas South C', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'South C', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10671, 'Cleanshelf South C', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'South C', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10672, 'Carrefour Nextgen', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Nextgen', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10673, 'Muhindi Mweusi South B', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10674, 'Naivas Mavoko', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mavoko', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10675, 'Chandarana Signature', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Signature', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10676, 'Skymart Mlolongo', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mlolongo', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10677, 'Cleanshelf Greenhouse', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Adams Arcade', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10678, 'Quickmart Mlolongo', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mlolongo', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10679, 'Chandarana Crystal', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Crystal', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10680, 'Quickmart pioneer Machakos', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10681, 'Quickmart Express Machakos', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Machakos', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10682, 'Raphymart', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Raphymart', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10683, 'Massmart', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Massmart', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10684, 'Ngooni', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngooni', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10685, 'Skymart Junction', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Junction', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10686, 'Naivas Gateway Mall', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mombasa Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10687, 'Naivas Airport', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Airport', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10688, 'Naivas Katani', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Katani', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10689, 'Eastmatt Kitengela', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Kitengela', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10690, 'Naivas Kitengela', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Kitengela', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10691, 'Quickmart Kitengela', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Kitengela', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10692, 'Eastmatt Kajiado', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kajiado', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10693, 'Powerstar Kitengela', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kitengela', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10694, 'Waeconmatt Kitengela', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Kitengela', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10695, 'Carrefour South field', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10696, 'Naivas Imaara', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Imaara', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10697, 'Quickmart Mombasa rd', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10698, 'Muhindi Mweusi Njenga', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Njenga', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10699, 'Naivas Express Embakasi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Embakasi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10700, 'Carrefour Ruiru', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ruiru', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10701, 'Quickmart Ruiru', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ruiru', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10702, 'Naivas Ananas', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ananas', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10703, 'Magunas Thika', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Thika', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10704, 'Waeconmatt Jomoko', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Jomoko', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10705, 'Muhindi Mweusi Weitaithie', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Weitaithie', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10706, 'Chokamat juja', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'juja', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10707, 'Mathais Matco', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Matco', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10708, 'Naivas Kahawa Sukari', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Sukari', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10709, 'Quickmart Kahawa Sukari', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Sukari', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10710, 'Naivas Githurai 45', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10711, 'Cleanshelf Wendani', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Wendani', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10712, 'Magunas Wendani', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Wendani', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10713, 'Naivas Northview', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Northview', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10714, 'Quickmart Thome', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Thome', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10715, 'Muhindi Mweusi Kariobangi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kariobangi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10716, 'Leester pioneer', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'pioneer', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10717, 'Leester Githurai', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Githurai', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10718, 'Naivas Lackey Summer', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Summer', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10719, 'Quickmart OTC', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'OTC', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10720, 'Quickmart mfangano', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'mfangano', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10721, 'Eastmatt Mfangano', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mfangano', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10722, 'Mathais OTC', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'OTC', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10723, 'Eastmatt River road', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10724, 'Quickmart pioneer', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'pioneer', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10725, 'Naivas Agakhan walk', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10726, 'Naivas Ronald Ngala', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngala', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10727, 'Chandarana Diamond', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Diamond', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10728, 'Chandarana Highridge', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Highridge', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10729, 'Naivas West', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'West', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10730, 'Naivas Ojijo', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ojijo', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10731, 'Naivas Mwanzi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mwanzi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10732, 'Quickmart West', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'West', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10733, 'Carrefour St Ellies CBD', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10734, 'Naivas Lifestyle', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Karen', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10735, 'Naivas Muindimbingu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Muindimbingu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10736, 'Eastmatt Tom Mboya', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Mboya', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10737, 'Quickmart Tom mboya', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10738, 'Carrefour Rongai', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Rongai', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10739, 'Naivas Maiyan', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Maiyan', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10740, 'Quickmart Kiserian', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kiserian', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10741, 'Quickmart Main', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Main', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10742, 'Quickmart Express Rongai', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Rongai', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10743, 'Naivas Langata', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Langata', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10744, 'Quickmart Tmall', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tmall', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10745, 'Cleanshelf Langata', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Langata', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10746, 'Naivas Medlink', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Langata', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10747, 'Carrefour Galleria', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Galleria', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10748, 'Chandarana The well', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10749, 'Naivas Home ground', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10750, 'Naivas Ngong 2', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10751, 'Cleanshelf Ngong', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngong', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10752, 'Magunas Ngong', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngong', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10753, 'Mathai Ngong', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngong', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10754, 'Quickmatt Milele', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Milele', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10755, 'Skymart Matasia', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Matasia', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10756, 'Naivas Tilisi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Tilisi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10757, 'Self ridges', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kikuyu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10758, 'Carrefour Sarit', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Sarit', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10759, 'Carrefour Spring Valley', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, 'Kabete', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10760, 'Chandarana ABC', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Westlands', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10761, 'Chandarana Azlea', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Azalea', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10762, 'Naivas Prestige', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Prestige', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10763, 'Chandarana yaya', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'yaya', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10764, 'Naivas Kilimani', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kilimani', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10765, 'Naivas Wood Avenue', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Avenue', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10766, 'Safeways Hurlingham', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Hurlingham', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10767, 'Carrefour Valley Arcade', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Valley Arcade', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10768, 'Naivas Lavington', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Lavington', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10769, 'Cleanshelf Lavington', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Lavington', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10770, 'Chandarana Lavington', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Lavington', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10771, 'Naivas Kangemi', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Kangemi', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10772, 'Naivas Mountain View', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Waiyaki way', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10773, 'Naivas Riruta', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Riruta', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10774, 'Quickmart Waithaka', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Waithaka', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10775, 'Skymart Kawangware', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kawangware', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10776, 'Naivas Ciata', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ciata', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10777, 'Quickmart Kiambu road', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Outer Ring Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10778, 'Chandarana Ridgeways', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ridgeways', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10779, 'Chandarana Mobil', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, '', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10780, 'Carrefour GTC', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, 'Kenya', 1, 'Kenya', 'N/A', NULL, '', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10781, 'Chandarana Riverside', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Riverside', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10782, 'Chandarana Ngara', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ngara', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10783, 'Cleanshelf Chiromo', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Chiromo', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10784, 'Quickmart Kileleshwa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kileleshwa', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10785, 'Carrefour Westgate', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Westgate', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10786, 'Carrefour Rhapta', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Rhapta Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10787, 'Chandarana Rhapta Road', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Rhapta Road', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10788, 'Quickmart Waiyaki Way', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Waiyaki way', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10789, 'Naivas Uthiru', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Uthiru', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10790, 'Leester Kinoo', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kinoo', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10791, 'Carrefour Rhunda', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Rhunda', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10792, 'Naivas Thindigwa', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Thindigwa', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10793, 'Naivas Kiambu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kiambu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10794, 'Cleanshelf Kiambu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Kiambu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10795, 'Chandarana Redhill', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Redhill', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10796, 'Magunas Gigiri', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Gigiri', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10797, 'Carrefour Village Market', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Limuru Rd', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10798, 'Quickmart Ruaka', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', 1, '', 1, '', 'N/A', NULL, 'Ruaka', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10799, 'Chandarana Thigiri', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Thigiri', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10800, 'Magunas Ndenderu', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ndenderu', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10801, 'Carrefour Two Rivers', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Limuru Rd', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10802, 'Cleanshelf Ruaka', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Ruaka', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099'),
(10803, 'Chandarana Rosslyn', NULL, -1.3009495, 36.7749168, NULL, NULL, 1, 'Nairobi', NULL, NULL, NULL, NULL, 'N/A', NULL, 'Westlands', 1, NULL, NULL, 0, 0.00, 1, 1, '2025-08-26 22:31:56.099');

-- --------------------------------------------------------

--
-- Table structure for table `client_ledger`
--

CREATE TABLE `client_ledger` (
  `id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `description` text NOT NULL,
  `reference_type` varchar(20) NOT NULL,
  `reference_id` int(11) NOT NULL,
  `debit` decimal(15,2) DEFAULT 0.00,
  `credit` decimal(15,2) DEFAULT 0.00,
  `running_balance` decimal(15,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `client_ledger`
--

INSERT INTO `client_ledger` (`id`, `client_id`, `date`, `description`, `reference_type`, `reference_id`, `debit`, `credit`, `running_balance`, `created_at`) VALUES
(1, 2, '2025-07-06', 'Invoice INV-2-1751827297786', 'sales_order', 2, 561.00, 0.00, 561.00, '2025-07-06 16:41:38'),
(2, 2, '2025-07-06', 'Invoice INV-2-1751827373685', 'sales_order', 3, 326.70, 0.00, 887.70, '2025-07-06 16:42:52'),
(3, 2, '2025-07-06', 'Invoice INV-2-1751828152710', 'sales_order', 4, 6600.00, 0.00, 7487.70, '2025-07-06 16:55:52'),
(4, 2, '2025-07-06', 'Payment RCP-2-1751828702405', 'receipt', 1, 0.00, 700.70, 6787.00, '2025-07-06 17:05:46'),
(6, 1, '2025-07-07', 'Invoice INV-1-1751897255494', 'sales_order', 6, 60.50, 0.00, 60.50, '2025-07-07 12:07:35'),
(7, 3, '2025-07-07', 'Invoice INV-3-1751897309177', 'sales_order', 7, 104.50, 0.00, 104.50, '2025-07-07 12:08:28'),
(8, 2, '2025-07-07', 'Invoice INV-2-1751912637004', 'sales_order', 8, 6600.00, 0.00, 13387.00, '2025-07-07 16:23:56'),
(10, 3, '2025-07-07', 'Invoice INV-3-1751913238102', 'sales_order', 10, 7920.00, 0.00, 8024.50, '2025-07-07 16:33:58'),
(11, 2, '2025-07-07', 'Invoice INV-2-1751918138904', 'sales_order', 11, 1089.00, 0.00, 14476.00, '2025-07-07 17:55:38'),
(12, 3, '2025-07-08', 'Invoice INV-3-1751996124894', 'sales_order', 12, 665.50, 0.00, 8690.00, '2025-07-08 15:35:24'),
(13, 1, '2025-07-08', 'Payment RCP-1-1751997946596', 'receipt', 2, 0.00, 60.50, 0.00, '2025-07-08 16:06:04'),
(14, 2, '2025-07-12', 'Invoice INV-2-1752309325399', 'sales_order', 13, 93.50, 0.00, 14569.50, '2025-07-12 06:35:24'),
(15, 3, '2025-07-12', 'Payment RCP-3-1752319722476', 'receipt', 3, 0.00, 8690.00, 0.00, '2025-07-12 09:29:10'),
(16, 2, '2025-07-12', 'Payment RCP-2-1752320067186', 'receipt', 4, 0.00, 400.00, 14169.50, '2025-07-12 09:34:57'),
(17, 2, '2025-07-12', 'Payment RCP-2-1752320092374', 'receipt', 5, 0.00, 300.00, 13869.50, '2025-07-12 09:37:04'),
(18, 2, '2025-07-12', 'Payment RCP-2-1752320457182', 'receipt', 6, 0.00, 210.00, 13659.50, '2025-07-12 09:41:07'),
(19, 2, '2025-07-12', 'Invoice INV-2-1752320810962', 'sales_order', 14, 60.50, 0.00, 13720.00, '2025-07-12 09:46:50'),
(20, 2, '2025-07-12', 'Invoice INV-2-1752321159077', 'sales_order', 15, 13200.00, 0.00, 26920.00, '2025-07-12 09:52:38'),
(21, 2, '2025-07-12', 'Payment RCP-2-1752322054452', 'receipt', 7, 0.00, 100.00, 26820.00, '2025-07-12 10:07:40'),
(22, 2, '2025-07-13', 'Invoice INV-2-1752397570019', 'sales_order', 16, 148.50, 0.00, 26968.50, '2025-07-13 07:06:07'),
(23, 2, '2025-07-13', 'Payment RCP-2-1752397788527', 'receipt', 8, 0.00, 400.00, 26568.50, '2025-07-13 07:09:59'),
(24, 2, '2025-07-13', 'Payment for invoice - testing', 'receipt', 9, 0.00, 40.00, 26528.50, '2025-07-13 07:37:17'),
(25, 2, '2025-07-13', 'Payment for invoice - 10', 'receipt', 10, 0.00, 200.00, 26328.50, '2025-07-13 07:48:16'),
(26, 2, '2025-07-13', 'Payment RCP-2-1752400098114', 'receipt', 10, 0.00, 200.00, 26128.50, '2025-07-13 07:59:17'),
(27, 2, '2025-07-13', 'Payment RCP-2-1752399439268', 'receipt', 9, 0.00, 40.00, 26088.50, '2025-07-13 07:59:58'),
(28, 2, '2025-07-13', 'Payment for invoice - 11', 'receipt', 11, 0.00, 30.50, 26058.00, '2025-07-13 08:17:40'),
(29, 2, '2025-07-13', 'Payment RCP-2-1752401862705', 'receipt', 11, 0.00, 30.50, 26027.50, '2025-07-13 08:18:09'),
(30, 2, '2025-07-13', 'Payment for invoice - 12', 'receipt', 12, 0.00, 35.00, 25992.50, '2025-07-13 08:24:37'),
(31, 2, '2025-07-16', 'Invoice INV-2-1752649457669', 'sales_order', 21, 99.00, 0.00, 26091.50, '2025-07-16 05:04:18'),
(32, 2, '2025-07-16', 'Payment for invoice - 13', 'receipt', 13, 0.00, 13200.00, 12891.50, '2025-07-16 15:52:50'),
(33, 2, '2025-07-16', 'Payment for invoice - 14', 'receipt', 14, 0.00, 148.50, 12743.00, '2025-07-16 15:52:51'),
(34, 2, '2025-07-16', 'Payment for invoice - 15', 'receipt', 15, 0.00, 99.00, 12644.00, '2025-07-16 15:52:52'),
(35, 2, '2025-07-16', 'Payment RCP-2-1752688372253', 'receipt', 15, 0.00, 99.00, 12545.00, '2025-07-17 10:37:50'),
(36, 2, '2025-07-17', 'Payment for invoice - 16', 'receipt', 16, 0.00, 93.50, 12451.50, '2025-07-17 11:03:35'),
(37, 2, '2025-07-17', 'Payment for invoice - 17', 'receipt', 17, 0.00, 60.50, 12391.00, '2025-07-17 11:03:36'),
(38, 168, '2025-07-27', 'Sales order - SO-1753903474059', 'sales_order', 35, 2200.00, 0.00, 2200.00, '2025-07-31 02:20:48'),
(39, 168, '2025-07-26', 'Sales order - SO-1753903474059', 'sales_order', 35, 2200.00, 0.00, 4400.00, '2025-07-31 02:24:34'),
(40, 168, '2025-07-25', 'Sales order - SO-1753903474059', 'sales_order', 35, 2200.00, 0.00, 4400.00, '2025-07-31 02:29:34'),
(41, 10171, '2025-07-29', 'Sales order - SO-1753900819864', 'sales_order', 33, 2200.00, 0.00, 2200.00, '2025-07-31 02:36:45'),
(42, 168, '2025-07-24', 'Sales order - SO-1753903474059', 'sales_order', 35, 2200.00, 0.00, 4400.00, '2025-07-31 02:42:04'),
(43, 10171, '2025-07-29', 'Invoice - INV-34', 'sales_order', 34, 2200.00, 0.00, 4400.00, '2025-07-31 02:47:03'),
(44, 2148, '2025-08-02', 'Sales order - SO-2025-0002', 'sales_order', 43, 2200.00, 0.00, 2200.00, '2025-08-02 11:31:16'),
(45, 2148, '2025-08-02', 'Sales order - SO-2025-0001', 'sales_order', 42, 11000.00, 0.00, 13200.00, '2025-08-02 11:56:46'),
(46, 2430, '2025-08-04', 'Invoice - INV-48', 'sales_order', 48, 2200.00, 0.00, 2200.00, '2025-08-03 22:57:44'),
(47, 168, '2025-08-04', 'Invoice - INV-55', 'sales_order', 55, 11000.00, 0.00, 13200.00, '2025-08-06 10:03:26'),
(48, 1796, '2025-08-06', 'Invoice - INV-56', 'sales_order', 56, 6600.00, 0.00, 6600.00, '2025-08-06 12:25:52'),
(49, 10171, '2025-08-06', 'Invoice - INV-57', 'sales_order', 57, 2200.00, 0.00, 6600.00, '2025-08-06 14:58:29'),
(50, 10171, '2025-08-06', 'Invoice - INV-58', 'sales_order', 58, 4400.00, 0.00, 11000.00, '2025-08-06 18:46:21'),
(51, 10171, '2025-08-06', 'Invoice - INV-59', 'sales_order', 59, 6600.00, 0.00, 17600.00, '2025-08-06 18:57:52'),
(52, 10171, '2025-08-06', 'Payment for invoice - test', 'receipt', 18, 0.00, 2000.00, 15600.00, '2025-08-06 19:31:11'),
(53, 10171, '2025-08-06', 'Payment RCP-10171-1754508671', 'receipt', 18, 0.00, 2000.00, 13600.00, '2025-08-06 19:39:18'),
(54, 10171, '2025-08-06', 'Payment RCP-10171-1754513370', 'receipt', 22, 0.00, 4.00, 13596.00, '2025-08-06 20:50:55'),
(55, 10171, '2025-08-07', 'Credit Note CN-1754530076209 - test', 'credit_note', 1, 0.00, 4000.00, 9596.00, '2025-08-07 01:28:07'),
(56, 10171, '2025-08-07', 'Credit Note CN-1754531048437 - n', 'credit_note', 2, 0.00, 2000.00, 7596.00, '2025-08-07 01:50:16'),
(57, 10171, '2025-08-07', 'Invoice - INV-60', 'sales_order', 60, 2200.00, 0.00, 9796.00, '2025-08-07 03:09:13'),
(58, 10171, '2025-08-07', 'Invoice - INV-61', 'sales_order', 61, 4400.00, 0.00, 14196.00, '2025-08-07 03:10:11'),
(59, 1796, '2025-08-07', 'Invoice - INV-65', 'sales_order', 65, 2000.00, 0.00, 8600.00, '2025-08-08 03:35:30'),
(60, 2221, '2025-08-09', 'Invoice - INV-70', 'sales_order', 70, 6000.00, 0.00, 6000.00, '2025-08-09 16:52:55'),
(61, 10171, '2025-08-05', 'Invoice - INV-64', 'sales_order', 64, 6000.00, 0.00, 20196.00, '2025-08-10 11:54:23'),
(62, 10171, '2025-08-10', 'Credit Note CN-10171-1754860285275', 'credit_note', 7, 0.00, 2000.00, 12196.00, '2025-08-10 21:11:24'),
(63, 10171, '2025-08-10', 'Credit Note CN-10171-1754860759831', 'credit_note', 8, 0.00, 4000.00, 8196.00, '2025-08-10 21:19:18'),
(64, 10171, '2025-08-10', 'Credit Note CN-10171-1754860809623', 'credit_note', 9, 0.00, 2000.00, 6196.00, '2025-08-10 21:20:08'),
(65, 10171, '2025-08-10', 'Credit Note CN-10171-1754860834263', 'credit_note', 10, 0.00, 2000.00, 4196.00, '2025-08-10 21:20:33'),
(66, 2221, '2025-08-10', 'Credit Note CN-2221-1754861688533', 'credit_note', 11, 0.00, 6000.00, 0.00, '2025-08-10 21:34:47'),
(67, 2221, '2025-08-12', 'Invoice - INV-71', 'sales_order', 71, 2000.00, 0.00, 2000.00, '2025-08-12 08:40:03'),
(68, 2221, '2025-08-12', 'Invoice - INV-72', 'sales_order', 72, 2000.00, 0.00, 4000.00, '2025-08-12 08:43:11'),
(69, 2221, '2025-08-19', 'Invoice - INV-73', 'sales_order', 73, 2000.00, 0.00, 6000.00, '2025-08-19 03:55:19'),
(70, 2221, '2025-08-19', 'Payment RCP-2221-17555766320', 'receipt', 24, 0.00, 2000.00, 4000.00, '2025-08-19 04:12:07'),
(71, 2221, '2025-08-19', 'Credit Note CN-2221-1755578549613', 'credit_note', 12, 0.00, 2000.00, 2000.00, '2025-08-19 04:42:28'),
(72, 389, '2025-08-19', 'Invoice - INV-74', 'sales_order', 74, 387.93, 0.00, 387.93, '2025-08-19 06:47:32'),
(73, 389, '2025-08-19', 'Invoice - INV-75', 'sales_order', 75, 450.00, 0.00, 837.93, '2025-08-19 06:54:38'),
(74, 2263, '2025-08-19', 'Invoice - INV-76', 'sales_order', 76, 3800.00, 0.00, 3800.00, '2025-08-19 09:45:13'),
(75, 389, '2025-08-19', 'Invoice - INV-77', 'sales_order', 77, 387.93, 0.00, 1225.86, '2025-08-19 09:53:46'),
(76, 389, '2025-08-19', 'Invoice - INV-78', 'sales_order', 78, 450.00, 0.00, 1675.86, '2025-08-19 09:57:01'),
(77, 2430, '2025-08-22', 'Invoice - INV-87', 'sales_order', 87, 200.00, 0.00, 2400.00, '2025-08-22 12:25:30'),
(78, 2430, '2025-08-22', 'Invoice - INV-88', 'sales_order', 88, 232.00, 0.00, 2632.00, '2025-08-22 13:45:32'),
(79, 2430, '2025-08-22', 'Invoice - INV-95', 'sales_order', 95, 2320.00, 0.00, 4952.00, '2025-08-22 14:16:26'),
(80, 267, '2025-08-25', 'Invoice - INV-96', 'sales_order', 96, 9600.00, 0.00, 9600.00, '2025-08-25 11:54:43'),
(81, 267, '2025-08-25', 'Invoice - INV-97', 'sales_order', 97, 10800.00, 0.00, 20400.00, '2025-08-25 12:02:01'),
(82, 1796, '2025-08-25', 'Invoice - INV-98', 'sales_order', 98, 1100.00, 0.00, 9700.00, '2025-08-25 12:48:56');

-- --------------------------------------------------------

--
-- Table structure for table `client_payments`
--

CREATE TABLE `client_payments` (
  `id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `invoice_id` int(11) DEFAULT NULL,
  `amount` decimal(15,2) NOT NULL,
  `account_id` int(11) DEFAULT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `payment_date` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `client_payments`
--

INSERT INTO `client_payments` (`id`, `customer_id`, `invoice_id`, `amount`, `account_id`, `reference`, `status`, `payment_date`, `created_at`, `updated_at`) VALUES
(1, 2, 15, 2.00, NULL, NULL, 'pending', '2025-07-14 00:00:00', '2025-07-15 21:24:34', '2025-07-15 22:06:42'),
(2, 2, 15, 20.00, NULL, 'testing', 'received', '2025-07-15 00:00:00', '2025-07-15 21:27:37', '2025-07-15 21:27:37'),
(3, 2, 15, 30.00, NULL, 'm', 'received', '2025-07-15 00:00:00', '2025-07-15 21:55:38', '2025-07-15 21:55:38'),
(4, 2, 15, 40.00, NULL, '88', 'pending', '2025-07-15 00:00:00', '2025-07-15 22:08:18', '2025-07-15 22:08:18');

-- --------------------------------------------------------

--
-- Table structure for table `Country`
--

CREATE TABLE `Country` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Country`
--

INSERT INTO `Country` (`id`, `name`, `status`) VALUES
(1, 'Kenya', 0),
(2, 'Tanzania', 0);

-- --------------------------------------------------------

--
-- Table structure for table `credit_notes`
--

CREATE TABLE `credit_notes` (
  `id` int(11) NOT NULL,
  `credit_note_number` varchar(50) NOT NULL,
  `client_id` int(11) NOT NULL,
  `original_invoice_id` int(11) DEFAULT NULL,
  `credit_note_date` date NOT NULL,
  `subtotal` decimal(11,2) NOT NULL,
  `tax_amount` decimal(11,2) NOT NULL,
  `net_price` decimal(11,2) NOT NULL,
  `total_amount` decimal(15,2) DEFAULT 0.00,
  `reason` text NOT NULL,
  `status` enum('draft','issued','cancelled') DEFAULT 'draft',
  `my_status` int(11) NOT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `received_by` int(11) NOT NULL,
  `received_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `credit_notes`
--

INSERT INTO `credit_notes` (`id`, `credit_note_number`, `client_id`, `original_invoice_id`, `credit_note_date`, `subtotal`, `tax_amount`, `net_price`, `total_amount`, `reason`, `status`, `my_status`, `created_by`, `created_at`, `updated_at`, `received_by`, `received_at`) VALUES
(1, 'CN-1754530076209', 10171, 0, '2025-08-07', 0.00, 0.00, 0.00, 4000.00, 'test', 'issued', 0, 1, '2025-08-07 01:27:55', '2025-08-07 01:28:07', 0, '0000-00-00 00:00:00'),
(2, 'CN-1754531048437', 10171, 0, '2025-08-07', 0.00, 0.00, 0.00, 2000.00, 'n', 'issued', 0, 1, '2025-08-07 01:44:07', '2025-08-07 01:50:15', 0, '0000-00-00 00:00:00'),
(7, 'CN-10171-1754860285275', 10171, NULL, '2025-08-10', 1724.14, 275.86, 0.00, 2000.00, '', '', 0, 1, '2025-08-10 21:11:24', '2025-08-10 21:11:24', 0, '0000-00-00 00:00:00'),
(8, 'CN-10171-1754860759831', 10171, NULL, '2025-08-10', 3448.28, 551.72, 0.00, 4000.00, '', '', 0, 1, '2025-08-10 21:19:18', '2025-08-10 21:19:18', 0, '0000-00-00 00:00:00'),
(9, 'CN-10171-1754860809623', 10171, NULL, '2025-08-10', 1724.14, 275.86, 0.00, 2000.00, '', '', 0, 1, '2025-08-10 21:20:08', '2025-08-10 21:20:08', 0, '0000-00-00 00:00:00'),
(10, 'CN-10171-1754860834263', 10171, NULL, '2025-08-10', 1724.14, 275.86, 0.00, 2000.00, '', '', 0, 1, '2025-08-10 21:20:33', '2025-08-10 21:20:33', 0, '0000-00-00 00:00:00'),
(11, 'CN-2221-1754861688533', 2221, NULL, '2025-08-10', 5172.41, 827.59, 0.00, 6000.00, '', '', 1, 1, '2025-08-10 21:34:47', '2025-08-11 03:49:59', 9, '2025-08-11 06:50:00'),
(12, 'CN-2221-1755578549613', 2221, NULL, '2025-08-19', 1724.14, 275.86, 0.00, 2000.00, '', '', 0, 1, '2025-08-19 04:42:28', '2025-08-19 04:42:28', 0, '0000-00-00 00:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `credit_note_items`
--

CREATE TABLE `credit_note_items` (
  `id` int(11) NOT NULL,
  `credit_note_id` int(11) NOT NULL,
  `invoice_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` decimal(10,2) NOT NULL,
  `unit_price` decimal(15,2) NOT NULL,
  `tax_amount` decimal(11,2) NOT NULL,
  `subtotal` decimal(11,2) NOT NULL,
  `total_price` decimal(15,2) NOT NULL,
  `net_price` decimal(11,2) NOT NULL,
  `reason` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `credit_note_items`
--

INSERT INTO `credit_note_items` (`id`, `credit_note_id`, `invoice_id`, `product_id`, `quantity`, `unit_price`, `tax_amount`, `subtotal`, `total_price`, `net_price`, `reason`, `created_at`) VALUES
(1, 1, 58, 7, 2.00, 2000.00, 0.00, 0.00, 4000.00, 0.00, 'test', '2025-08-07 01:27:55'),
(2, 2, 58, 7, 1.00, 2000.00, 0.00, 0.00, 2000.00, 0.00, 'n', '2025-08-07 01:44:08'),
(4, 7, 60, 7, 1.00, 2000.00, 275.86, 0.00, 2000.00, 1724.14, '', '2025-08-10 21:11:24'),
(5, 8, 61, 7, 2.00, 2000.00, 551.72, 0.00, 4000.00, 3448.28, '', '2025-08-10 21:19:18'),
(6, 9, 60, 7, 1.00, 2000.00, 275.86, 0.00, 2000.00, 1724.14, '', '2025-08-10 21:20:08'),
(7, 10, 60, 7, 1.00, 2000.00, 275.86, 0.00, 2000.00, 1724.14, '', '2025-08-10 21:20:33'),
(8, 11, 70, 7, 3.00, 2000.00, 827.59, 0.00, 6000.00, 5172.41, '', '2025-08-10 21:34:47'),
(9, 12, 71, 7, 1.00, 2000.00, 275.86, 0.00, 2000.00, 1724.14, '', '2025-08-19 04:42:28');

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

CREATE TABLE `customers` (
  `id` int(11) NOT NULL,
  `customer_code` varchar(20) NOT NULL,
  `company_name` varchar(100) NOT NULL,
  `contact_person` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `tax_id` varchar(50) DEFAULT NULL,
  `payment_terms` int(11) DEFAULT 30,
  `credit_limit` decimal(15,2) DEFAULT 0.00,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `country_id` int(11) DEFAULT NULL,
  `region_id` int(11) DEFAULT NULL,
  `route_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`id`, `customer_code`, `company_name`, `contact_person`, `email`, `phone`, `address`, `tax_id`, `payment_terms`, `credit_limit`, `is_active`, `created_at`, `updated_at`, `country_id`, `region_id`, `route_id`) VALUES
(1, 'CUST001', 'Tech Solutions Inc.', 'Alice Johnson', 'alice@techsolutions.com', '+1-555-0201', '100 Tech Plaza, San Francisco, CA 94105', 'CUST123456', 30, 100000.00, 1, '2025-07-06 08:32:52', '2025-07-06 08:32:52', NULL, NULL, NULL),
(2, 'CUST002', 'Digital Innovations', 'Bob Davis', 'bob@digitalinnovations.com', '+1-555-0202', '200 Innovation Drive, Seattle, WA 98101', 'CUST789012', 45, 75000.00, 1, '2025-07-06 08:32:53', '2025-07-06 08:32:53', NULL, NULL, NULL),
(3, 'CUST003', 'Smart Systems', 'Carol White', 'carol@smartsystems.com', '+1-555-0203', '300 Smart Street, New York, NY 10001', 'CUST345678', 30, 150000.00, 1, '2025-07-06 08:32:53', '2025-07-06 08:32:53', NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

CREATE TABLE `departments` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`id`, `name`) VALUES
(1, 'Admin'),
(2, 'Finance'),
(3, 'Department Admin'),
(4, 'Manager'),
(5, 'HR'),
(6, 'Inventory');

-- --------------------------------------------------------

--
-- Table structure for table `distributors_targets`
--

CREATE TABLE `distributors_targets` (
  `id` int(11) NOT NULL,
  `sales_rep_id` int(11) NOT NULL,
  `vapes_targets` int(11) DEFAULT 0,
  `pouches_targets` int(11) DEFAULT 0,
  `new_outlets_targets` int(11) DEFAULT 0,
  `target_month` varchar(7) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `start_date` date NOT NULL,
  `end_date` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `distributors_targets`
--

INSERT INTO `distributors_targets` (`id`, `sales_rep_id`, `vapes_targets`, `pouches_targets`, `new_outlets_targets`, `target_month`, `created_at`, `start_date`, `end_date`) VALUES
(1, 4, 2, 2, 1, '2025-07', '2025-07-18 08:14:09', '2025-07-01', '2025-07-30');

-- --------------------------------------------------------

--
-- Table structure for table `documents`
--

CREATE TABLE `documents` (
  `id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `file_url` varchar(255) NOT NULL,
  `category` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `documents`
--

INSERT INTO `documents` (`id`, `title`, `file_url`, `category`, `description`, `uploaded_at`) VALUES
(1, 'n', '/uploads/acf5d97d808817de2f5cc8cda48bc1f2', 'Contract', NULL, '2025-07-10 13:50:03'),
(2, 'n', 'https://res.cloudinary.com/otienobryan/image/upload/v1752162730/documents/1752162730265_5.jpg.jpg', 'Contract', NULL, '2025-07-10 13:52:10'),
(3, 'bn', 'https://res.cloudinary.com/otienobryan/image/upload/v1752162780/documents/1752162780528_8.jpg.jpg', 'Agreement', NULL, '2025-07-10 13:53:00'),
(4, 'nmm', 'https://res.cloudinary.com/otienobryan/image/upload/v1752162807/documents/1752162807345_8.jpg.jpg', 'Agreement', NULL, '2025-07-10 13:53:27');

-- --------------------------------------------------------

--
-- Table structure for table `employee_contracts`
--

CREATE TABLE `employee_contracts` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `renewed_from` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `employee_contracts`
--

INSERT INTO `employee_contracts` (`id`, `staff_id`, `file_name`, `file_url`, `start_date`, `end_date`, `uploaded_at`, `renewed_from`) VALUES
(1, 3, '1.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752134467/employee_contracts/3_1752134467309_1.jpg.jpg', '2025-07-10', '2025-07-29', '2025-07-10 06:01:07', NULL),
(2, 8, 'logo_maa.pdf', 'https://res.cloudinary.com/otienobryan/image/upload/v1753772558/employee_contracts/8_1753772558318_logo_maa.pdf.pdf', '2025-07-01', '2025-07-29', '2025-07-29 05:02:38', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `employee_documents`
--

CREATE TABLE `employee_documents` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_url` varchar(255) NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `description` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `employee_documents`
--

INSERT INTO `employee_documents` (`id`, `staff_id`, `file_name`, `file_url`, `uploaded_at`, `description`) VALUES
(4, 3, '5.jpg', '/uploads/d78ae353a82450a69d7c614879ffe5df', '2025-07-09 15:01:31', NULL),
(5, 3, '9.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752081837/employee_documents/3_1752081836571_9.jpg.jpg', '2025-07-09 15:23:59', NULL),
(6, 3, '4.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752081888/employee_documents/3_1752081887870_4.jpg.jpg', '2025-07-09 15:24:47', NULL),
(9, 2, '1.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082369/employee_documents/2_1752082369493_1.jpg.jpg', '2025-07-09 15:32:49', NULL),
(10, 2, '1.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082374/employee_documents/2_1752082374322_1.jpg.jpg', '2025-07-09 15:32:53', 'ddd'),
(11, 2, '6.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082536/employee_documents/2_1752082536277_6.jpg.jpg', '2025-07-09 15:35:35', NULL),
(12, 2, '6.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082552/employee_documents/2_1752082552405_6.jpg.jpg', '2025-07-09 15:35:51', 'nn'),
(13, 2, '6.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082850/employee_documents/2_1752082849951_6.jpg.jpg', '2025-07-09 15:40:49', 'nn'),
(14, 2, '1.jpg', 'https://res.cloudinary.com/otienobryan/image/upload/v1752082864/employee_documents/2_1752082864399_1.jpg.jpg', '2025-07-09 15:41:04', NULL),
(17, 8, 'OSCU_VSCU_Step-by-Step_Guide-on-how-to-sign-up.pdf', 'https://res.cloudinary.com/otienobryan/image/upload/v1753770383/employee_documents/9_1753770383649_attendance.png.png', '2025-07-29 04:17:18', 'tet'),
(18, 9, 'attendance.png', 'https://res.cloudinary.com/otienobryan/image/upload/v1753770383/employee_documents/9_1753770383649_attendance.png.png', '2025-07-29 04:26:23', NULL),
(19, 9, 'avail.png', 'https://res.cloudinary.com/otienobryan/image/upload/v1753772780/employee_documents/9_1753772780091_avail.png.png', '2025-07-29 05:06:20', 'nn'),
(20, 8, 'azure.png', 'https://res.cloudinary.com/otienobryan/image/upload/v1753772831/employee_documents/8_1753772831907_azure.png.png', '2025-07-29 05:07:11', 'test');

-- --------------------------------------------------------

--
-- Table structure for table `employee_warnings`
--

CREATE TABLE `employee_warnings` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `message` text NOT NULL,
  `issued_by` varchar(100) DEFAULT NULL,
  `issued_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `employee_warnings`
--

INSERT INTO `employee_warnings` (`id`, `staff_id`, `message`, `issued_by`, `issued_at`) VALUES
(2, 3, 'nn', NULL, '2025-07-10 08:20:28'),
(3, 3, 'hhhj', NULL, '2025-07-28 09:26:00');

-- --------------------------------------------------------

--
-- Table structure for table `faulty_products_items`
--

CREATE TABLE `faulty_products_items` (
  `id` int(11) NOT NULL,
  `report_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `fault_comment` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `faulty_products_items`
--

INSERT INTO `faulty_products_items` (`id`, `report_id`, `product_id`, `quantity`, `fault_comment`, `created_at`, `updated_at`) VALUES
(2, 3, 15, 13, '4', '2025-07-30 13:46:35', '2025-07-30 13:46:35'),
(3, 3, 11, 12, 'yy', '2025-07-30 13:46:35', '2025-07-30 13:46:35'),
(4, 4, 7, 100, '40', '2025-07-30 14:01:23', '2025-07-30 14:01:23'),
(5, 4, 6, 1, 'gg', '2025-07-30 14:01:23', '2025-07-30 14:01:23'),
(6, 5, 5, 1, 'nnn', '2025-07-30 14:31:49', '2025-07-30 14:31:49');

-- --------------------------------------------------------

--
-- Table structure for table `faulty_products_reports`
--

CREATE TABLE `faulty_products_reports` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `reported_by` int(11) NOT NULL,
  `reported_date` date NOT NULL,
  `status` enum('Reported','Under Investigation','Being Repaired','Repaired','Replaced','Disposed','Closed') DEFAULT 'Reported',
  `assigned_to` int(11) DEFAULT NULL,
  `resolution_notes` text DEFAULT NULL,
  `document_url` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `faulty_products_reports`
--

INSERT INTO `faulty_products_reports` (`id`, `store_id`, `reported_by`, `reported_date`, `status`, `assigned_to`, `resolution_notes`, `document_url`, `created_at`, `updated_at`) VALUES
(3, 1, 7, '2025-07-30', 'Reported', NULL, NULL, NULL, '2025-07-30 13:46:35', '2025-07-30 13:46:35'),
(4, 1, 7, '2025-07-30', 'Reported', NULL, NULL, NULL, '2025-07-30 14:01:23', '2025-07-30 14:01:23'),
(5, 1, 7, '2025-07-30', 'Reported', NULL, NULL, NULL, '2025-07-30 14:31:49', '2025-07-30 14:31:49');

-- --------------------------------------------------------

--
-- Table structure for table `FeedbackReport`
--

CREATE TABLE `FeedbackReport` (
  `reportId` int(11) DEFAULT NULL,
  `comment` varchar(191) DEFAULT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `clientId` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  `userId` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `FeedbackReport`
--

INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(295, 'the movement is very slow even when we send a B.A', '2025-05-21 07:28:38.904', 10605, 5, 39),
(299, 'we will place orders for pouches next week Monday ', '2025-05-21 07:36:36.591', 10605, 6, 31),
(300, 'we are placing orders for 3000puffs and 9000puffs ', '2025-05-21 07:39:36.986', 10605, 7, 31),
(302, 'Placed an order for items not in stock', '2025-05-21 07:49:04.391', 10605, 8, 30),
(305, 'moving slowly ', '2025-05-21 07:53:56.152', 10605, 9, 63),
(309, 'the movement is a little bit slow but better than last month ', '2025-05-21 08:17:07.179', 10605, 10, 39),
(312, 'stock is stagnant especially vapes\n', '2025-05-21 08:20:15.329', 10605, 11, 50),
(320, 'the movement is okay ', '2025-05-21 08:47:04.625', 10605, 12, 39),
(323, 'they are not ready to place an order ,,\n', '2025-05-21 08:48:43.110', 10605, 13, 50),
(324, 'Movement picking slow', '2025-05-21 08:48:55.670', 10605, 14, 30),
(327, 'Atlantis has few stocks on 9000 puffs . ', '2025-05-21 08:51:42.971', 10605, 15, 26),
(330, 'their boss is yet to approve in stocking woosh products ,,the manager said', '2025-05-21 09:04:41.467', 10605, 16, 50),
(334, 'To share their LPO on email', '2025-05-21 09:14:40.489', 10605, 17, 23),
(344, 'waiting for 5dots', '2025-05-21 09:27:24.546', 10605, 18, 63),
(349, 'The movement is quite slow ', '2025-05-21 09:36:06.871', 10605, 19, 39),
(350, 'following up for a reorder, met Salima the manager over this', '2025-05-21 09:36:15.420', 10605, 20, 35),
(353, 'Concern over minty snow\nplaced a small order ', '2025-05-21 09:45:45.236', 10605, 21, 30),
(356, 'they have zero stock they don\'t want the 3 dot ', '2025-05-21 09:53:21.166', 10605, 22, 39),
(359, 'well stocked ', '2025-05-21 10:04:58.357', 10605, 23, 63),
(362, 'the movement is okay ', '2025-05-21 10:09:55.335', 10605, 24, 39),
(367, 'They needed the five dot which are currently out of stock', '2025-05-21 10:38:58.659', 10605, 25, 51),
(369, 'well stocked ', '2025-05-21 10:39:37.526', 10605, 26, 63),
(372, 'Business is slow we check in the course of next week ', '2025-05-21 10:52:46.190', 10605, 27, 30),
(376, 'Completed renovation of their restaurant. Low season is affecting sales.', '2025-05-21 11:32:22.282', 10605, 28, 57),
(378, 'Requesting 5dots ', '2025-05-21 11:33:24.260', 10605, 29, 30),
(381, 'the movement is okay ', '2025-05-21 11:38:08.593', 10605, 30, 39),
(384, 'Stock report will be completed at the end of the week. ', '2025-05-21 11:58:54.110', 10605, 31, 57),
(386, 'Flavour exchange has been authorised by Tanya at Moonsun and Helen MD of Kioko Distributors.', '2025-05-21 12:12:13.193', 10605, 32, 57),
(389, 'They have adjusted prices but no sales. They have had the same stock for 3 weeks.', '2025-05-21 12:20:05.589', 10605, 33, 57),
(394, 'the movement is slow ', '2025-05-21 12:30:44.450', 10605, 34, 39),
(405, 'the 5dot pouches are better and stimulating well', '2025-05-21 13:29:03.914', 10605, 35, 44),
(411, 'well stocked ', '2025-05-21 13:53:50.428', 10605, 36, 7),
(414, 'To make an order after payment is made .', '2025-05-22 06:45:39.374', 10605, 37, 51),
(417, 'They\'re doing well. waiting for the order to be delivered ', '2025-05-22 07:34:01.003', 10605, 38, 21),
(420, 'Everything is okay. They\'re waiting for their order to be delivered ', '2025-05-22 07:35:19.548', 10605, 39, 21),
(423, 'They will order more vapes after 5 dot pouches return.', '2025-05-22 07:38:22.333', 10605, 40, 57),
(425, 'Pending order', '2025-05-22 07:39:46.884', 10605, 41, 30),
(427, 'Mounting needed', '2025-05-22 07:45:58.632', 10605, 42, 30),
(429, 'Awaiting for 5dots', '2025-05-22 07:49:17.705', 10605, 43, 30),
(432, 'The 5 dots are being asked for by customers', '2025-05-22 07:59:59.282', 10605, 44, 51),
(433, 'they are yet to stock the products', '2025-05-22 08:00:02.154', 10605, 45, 50),
(434, 'they have not stocked woosh products', '2025-05-22 08:10:36.248', 10605, 46, 50),
(444, 'They\'re well stocked ', '2025-05-22 08:39:38.549', 10605, 47, 21),
(445, 'order tomorrow ', '2025-05-22 08:40:17.367', 10605, 48, 63),
(451, 'cooling mint doing well in shell outering road ', '2025-05-22 08:59:11.671', 10605, 49, 26),
(454, 'stock moving smoothly \n9000 puffs 7 rrp 2200\n3000 puffs 5 rrp 1500\ngps 14 rrp 550', '2025-05-22 09:02:03.945', 10605, 50, 50),
(456, 'They place another order on 1st', '2025-05-22 09:04:25.074', 10605, 51, 22),
(459, 'No stock ', '2025-05-22 09:09:19.765', 10605, 52, 63),
(460, 'no stock ', '2025-05-22 09:09:42.555', 10605, 53, 63),
(462, 'Still waiting for a display ', '2025-05-22 09:13:15.818', 10605, 54, 30),
(474, 'the management is requesting to sale pouches since vape is moving slowly ', '2025-05-22 09:34:47.779', 10605, 55, 22),
(475, 'I have negotiated with them to change the pricing on the 3000 puffs which they had raised from 1500 to 2000 back to 1700', '2025-05-22 09:35:47.236', 10605, 56, 50),
(478, 'The outlet has a pending invoice to be paid, this can not place an order', '2025-05-22 09:38:05.824', 10605, 57, 23),
(493, 'well stocked', '2025-05-22 10:04:58.647', 10605, 58, 63),
(498, 'They still have enough stock\n', '2025-05-22 10:10:57.615', 10605, 59, 22),
(504, 'they need only 5dots to reoder', '2025-05-22 10:21:12.172', 10605, 60, 50),
(508, '7pcs juicy grape 2500 needs to be picked', '2025-05-22 10:36:07.202', 10605, 61, 30),
(509, 'it\'s under Mesmet dealership and the owner communicated no orders are to be placed till June.', '2025-05-22 10:46:06.372', 10605, 62, 23),
(513, 'The competitor in this market is hart and booster', '2025-05-22 11:00:26.809', 10605, 63, 51),
(515, 'Still looking for someone reliable to do Activation here', '2025-05-22 11:01:54.817', 10605, 64, 57),
(521, 'The are well stocked ', '2025-05-22 11:20:22.041', 10605, 65, 22),
(523, 'made orders yet to receive them', '2025-05-22 11:21:46.631', 10605, 66, 31),
(526, 'Movement abit slow ', '2025-05-22 11:24:36.366', 10605, 67, 30),
(527, 'placing order on monday', '2025-05-22 11:29:07.518', 10605, 68, 63),
(530, 'to place an order on Wednesday for pouches', '2025-05-22 11:40:30.961', 10605, 69, 35),
(535, 'following up on boarding. ', '2025-05-22 11:48:06.806', 10605, 70, 35),
(537, 'Collected GRN', '2025-05-22 11:49:39.046', 10605, 71, 57),
(544, 'Display is required for carrefour spring valley ', '2025-05-22 12:04:16.608', 10605, 72, 51),
(545, 'following up on boarding, to make an order at the end of the month ', '2025-05-22 12:04:27.197', 10605, 73, 35),
(549, 'Interested in the 5 dots Gold pouch\n', '2025-05-22 12:12:17.758', 10605, 74, 35),
(553, 'Vapes movement is slow ', '2025-05-22 12:26:51.487', 10605, 75, 30),
(555, 'cleared their pending bill yet to make a reorder of pouches and vapes', '2025-05-22 12:28:30.765', 10605, 76, 35),
(557, 'the outlet is okay selling quite well', '2025-05-22 12:39:05.669', 10605, 77, 52),
(561, 'They\'re not recieving 3000puffs but 9000puffs is coming in ', '2025-05-22 12:45:45.941', 10605, 78, 21),
(567, 'the movement is okay ', '2025-05-22 13:17:58.538', 10605, 79, 39),
(571, 'the moment is very okay ', '2025-05-22 13:29:28.349', 10605, 80, 39),
(574, 'have talked to the supervisor said I call him tomorrow for the feedvack', '2025-05-22 13:36:11.266', 10605, 81, 50),
(582, 'cleanshelf kiambu\nthey have sent mail asking for our codes to place orders', '2025-05-23 07:28:55.127', 10605, 82, 62),
(585, 'to make an order on 1st', '2025-05-23 07:41:55.941', 10605, 83, 35),
(588, 'requesting for price reduction ', '2025-05-23 07:46:57.187', 10605, 84, 26),
(593, 'No stocks for Gold pouches and some flavors of vapes but we\'ve placed order.', '2025-05-23 08:02:20.736', 10605, 85, 21),
(597, 'stock moving slowly', '2025-05-23 08:03:50.941', 10605, 86, 50),
(602, 'well stocked ', '2025-05-23 08:13:49.772', 10605, 87, 63),
(604, 'Naivas Hyper Kisii ', '2025-05-23 08:16:23.478', 10605, 88, 35),
(607, 'we did an order waiting for delivery ', '2025-05-23 08:27:40.484', 10605, 89, 20),
(610, 'They are well stocked ', '2025-05-23 08:40:25.961', 10605, 90, 22),
(615, 'the outlet is very stocked ', '2025-05-23 08:47:55.933', 10605, 91, 26),
(617, 'placing order next week', '2025-05-23 08:51:25.390', 10605, 92, 63),
(623, 'The 9000puffs is slow. Clients are asking about 5dot.', '2025-05-23 09:06:05.609', 10605, 93, 51),
(625, 'They are well stocked \nThe movement is okay ', '2025-05-23 09:07:56.518', 10605, 94, 22),
(627, 'carrefour garden city not yet received stock', '2025-05-23 09:18:13.589', 10605, 95, 63),
(630, 'requesting an exchange of the 3dots with five dots . placing an order today', '2025-05-23 09:21:38.961', 10605, 96, 35),
(633, 'The sales are good and the outlet is well stocked ', '2025-05-23 09:23:29.339', 10605, 97, 21),
(634, 'this a new outlet we have agreed on term just waiting for orders from them', '2025-05-23 09:23:30.116', 10605, 98, 31),
(639, 'They are out of stocks they are waiting for the order ', '2025-05-23 09:27:10.529', 10605, 99, 22),
(643, 'The outlet does not need a display currently. \nThe clients are inquiring about the five dot which will be stocked once the 3 dot have reduced in number.', '2025-05-23 09:31:15.129', 10605, 100, 51),
(644, 'No vape sold so far yet no competitor', '2025-05-23 09:31:29.797', 10605, 101, 50),
(647, 'The cooling mint is moving quickly .\nClients are requesting for 3dot.', '2025-05-23 09:37:54.386', 10605, 102, 51),
(648, 'Clients are requesting for 5dot.', '2025-05-23 09:38:29.078', 10605, 103, 51),
(650, 'Trying to onboard them', '2025-05-23 09:41:23.884', 10605, 104, 59),
(657, '3 pieces of 3000 puffs but he is yet to clear the previous invoice to make a reoder', '2025-05-23 10:03:01.639', 10605, 105, 50),
(662, 'They still well stocked ', '2025-05-23 10:26:39.383', 10605, 106, 22),
(669, 'Placed an order for the 5dot.', '2025-05-23 10:33:17.071', 10605, 107, 51),
(679, 'pushing for a restock ', '2025-05-23 10:48:18.882', 10605, 108, 39),
(683, 'pushing for a restock ', '2025-05-23 10:51:18.771', 10605, 109, 39),
(688, 'stock exchange needed at Naivas mountain mall.\nmoving slowly ', '2025-05-23 10:55:26.096', 10605, 110, 63),
(689, 'They are going to make a reorder of the pouches and the vapes.Clients were already inquiring about the availability of the 5 dot.', '2025-05-23 10:56:13.021', 10605, 111, 51),
(693, 'stock moving slowly', '2025-05-23 10:58:37.516', 10605, 112, 50),
(695, 'They are overstocked. We will place an order for 5 dots next week.', '2025-05-23 10:59:58.687', 10605, 113, 91),
(707, 'slow selling on the 9000 puffs ', '2025-05-23 11:23:14.435', 10605, 114, 50),
(715, 'They are well stocked ', '2025-05-23 11:29:37.504', 10605, 115, 22),
(724, 'Sold out will place order next month.', '2025-05-23 11:39:18.987', 10605, 116, 57),
(728, 'Customers are requesting for minty snow.The 9000puffs are fast moving.', '2025-05-23 11:52:53.252', 10605, 117, 51),
(733, 'They\'re doing well in sales and we\'ve placed another order ', '2025-05-23 11:57:17.355', 10605, 118, 21),
(738, 'well stocked ', '2025-05-23 12:04:20.439', 10605, 119, 63),
(742, 'low stock on vape they will reorder on Monday ', '2025-05-23 12:26:22.858', 10605, 120, 31),
(746, 'well stocked with the 3k puffs and 9k puffs ', '2025-05-23 12:43:03.099', 10605, 121, 63),
(749, 'they\'ve not sold by piece since I onboarded them ', '2025-05-23 12:55:53.069', 10605, 122, 21),
(751, 'Slow movement of products', '2025-05-23 12:57:41.461', 10605, 123, 91),
(755, 'movement is good ', '2025-05-23 13:09:35.096', 10605, 124, 31),
(757, 'made Reordered today', '2025-05-23 13:12:13.292', 10605, 125, 31),
(759, 'order for pouches to be placed ', '2025-05-23 13:13:13.752', 10605, 126, 20),
(765, 'the outlet is pressuring for GP ... which are yet to be delivered ', '2025-05-23 13:37:04.061', 10605, 127, 26),
(770, 'to place another order on Monday ', '2025-05-23 14:54:40.266', 10605, 128, 26),
(774, 'slow sales so far in the previous months', '2025-05-23 15:34:22.682', 10605, 129, 35),
(780, 'They are a new client.One piece has been sold already.', '2025-05-24 06:29:34.308', 10605, 130, 51),
(781, 'Hart is a competitor .', '2025-05-24 06:30:20.701', 10605, 131, 51),
(784, 'manager is absent', '2025-05-24 07:03:43.933', 10605, 132, 62),
(789, 'They\'re doing well and well stocked ', '2025-05-24 07:28:09.245', 10605, 133, 21),
(791, 'They currently have no pouches.The pouches are moving faster and are to make a reorder.', '2025-05-24 07:35:53.421', 10605, 134, 51),
(796, 'They have made a reorder of pouches and ice sparkling orange vape.', '2025-05-24 07:46:55.612', 10605, 135, 51),
(798, 'In need of a display ', '2025-05-24 07:54:56.652', 10605, 136, 73),
(806, 'They need our own display ', '2025-05-24 08:16:13.301', 10605, 137, 73),
(808, 'placed an order with dantra', '2025-05-24 08:18:58.839', 10605, 138, 62),
(813, 'They are well stocked ', '2025-05-24 08:24:14.472', 10605, 139, 22),
(814, 'Collecting returns and return sheets', '2025-05-24 08:27:54.105', 10605, 140, 57),
(821, '3000 puffs is selling more than 9000 puffs', '2025-05-24 08:42:24.062', 10605, 141, 20),
(829, 'The movement is very fast ', '2025-05-24 08:52:00.925', 10605, 142, 22),
(830, 'following up on a cash on order delivery because they had an issue with payments', '2025-05-24 08:52:37.855', 10605, 143, 35),
(835, 'Wil display next week', '2025-05-24 08:56:00.339', 10605, 145, 74),
(841, 'collecting return sheet', '2025-05-24 09:08:26.496', 10605, 146, 57),
(844, 'We are placing another order,she had requested we created account for them of am still waiting for the feedback ', '2025-05-24 09:11:23.041', 10605, 147, 22),
(848, 'stock moving quite well especially 9000 puffs', '2025-05-24 09:20:50.163', 10605, 148, 50),
(852, 'well stocked but 3dots moving slowly ', '2025-05-24 09:35:41.123', 10605, 149, 63),
(855, 'Movement of products affected by no dispay policy by kiambu county ', '2025-05-24 09:42:11.108', 10605, 150, 30),
(862, 'empty display which is not used again am taking it back to the offices', '2025-05-24 09:55:00.123', 10605, 151, 62),
(864, 'stock moving smoothly\n9000 puffs 2200\n3000 puffs 1500\ngps rrp 550', '2025-05-24 09:56:46.640', 10605, 152, 50),
(866, 'collecting return sheet', '2025-05-24 10:09:20.764', 10605, 153, 57),
(869, 'They received their order ', '2025-05-24 10:25:00.068', 10605, 154, 63),
(874, 'well stocked ', '2025-05-24 11:26:51.297', 10605, 155, 63),
(877, 'more to be done on visibility. the space is small', '2025-05-24 11:53:59.197', 10605, 156, 26),
(942, 'The competitor is gogo.\nThe 3000puffs are moving faster than the 9000puffs.', '2025-05-26 06:48:04.352', 10605, 160, 51),
(946, 'placed an order today', '2025-05-26 06:58:04.096', 10605, 161, 62),
(949, 'They are well stocked and products are moving well', '2025-05-26 07:09:01.728', 10605, 162, 19),
(957, 'well stocked for now ', '2025-05-26 07:46:16.978', 10605, 163, 7),
(965, 'They are asking for an exchange of the 2500puffs for 3k puffs ', '2025-05-26 07:51:56.823', 10605, 164, 19),
(971, 'They are well stocked ', '2025-05-26 08:07:46.490', 10605, 165, 22),
(974, 'movement on pouches is good at this outlet \ncould not make orders since they are doing stock taking they promised to make an order at the start of next month ', '2025-05-26 08:11:04.982', 10605, 166, 31),
(976, 'outlet to clear the previous debt to place order. ', '2025-05-26 08:13:19.344', 10605, 167, 26),
(979, '3000puffs codea still inactive hence can\'t place an order', '2025-05-26 08:18:16.639', 10605, 168, 30),
(985, 'The products are moving slowly. \nThe clients are asking for 5dot .This a stock  of 3 dot which they are waiting to reduce before making a reorder.', '2025-05-26 08:22:13.954', 10605, 169, 51),
(997, 'Staff requesting timeline for B-C\nPending payments will be cleared next month. ', '2025-05-26 08:32:15.722', 10605, 170, 57),
(1000, 'well stocked', '2025-05-26 08:35:14.141', 10605, 171, 63),
(1004, 'sales are moving but slowly ', '2025-05-26 08:35:59.762', 10605, 172, 73),
(1010, 'Business is slow, no order at the moment ', '2025-05-26 08:40:42.093', 10605, 173, 30),
(1014, ' will order next month', '2025-05-26 08:44:10.898', 10605, 174, 62),
(1017, 'still following up on orders', '2025-05-26 08:45:18.366', 10605, 175, 35),
(1020, 'The order was delivered but not all the flavors as per the order sheet ', '2025-05-26 08:46:35.396', 10605, 176, 21),
(1023, 'following up on orders and boarding ', '2025-05-26 08:47:48.072', 10605, 177, 35),
(1024, 'Still pushi g for an order of vapes.The pouches are moving quickly to reorder by the end of this week.', '2025-05-26 08:48:11.920', 10605, 178, 51),
(1027, 'Booster is the competitor in this market.\nThere are hart vapes.', '2025-05-26 08:49:51.383', 10605, 179, 51),
(1029, '9000 puffs moving well', '2025-05-26 08:50:35.779', 10605, 180, 50),
(1036, 'in need of stocks.', '2025-05-26 08:58:47.470', 10605, 181, 46),
(1039, 'They are well stocked ', '2025-05-26 09:00:07.201', 10605, 182, 22),
(1041, 'No sales made due to low season, affecting payments. ', '2025-05-26 09:01:18.488', 10605, 183, 57),
(1052, 'waiting on 5 dot\nwill order on 3 dots', '2025-05-26 09:03:29.441', 10605, 184, 64),
(1068, 'sales have been a bit slow', '2025-05-26 09:08:02.350', 10605, 185, 35),
(1090, 'They\'ll do transfer from Makuyu ', '2025-05-26 09:18:09.521', 10605, 186, 22),
(1100, 'stock moving slowly no competitor', '2025-05-26 09:20:00.135', 10605, 187, 50),
(1104, 'Will place an order soon', '2025-05-26 09:21:55.524', 10605, 188, 49),
(1115, 'The outlet has closed in order placement, They will place a new order next month ', '2025-05-26 09:28:42.183', 10605, 189, 23),
(1118, 'Most of Blue Razz are faulty ', '2025-05-26 09:29:45.114', 10605, 190, 73),
(1122, 'well stocked with 3k puffs and 9k puffs ', '2025-05-26 09:32:01.673', 10605, 191, 63),
(1126, 'the display is well set', '2025-05-26 09:35:07.484', 10605, 192, 39),
(1131, 'They are asking for a merchandiser ', '2025-05-26 09:40:17.731', 10605, 193, 19),
(1134, 'the movement is very slow ', '2025-05-26 09:42:42.392', 10605, 194, 39),
(1139, 'Following up on their interest to try our products.\nTold maager will be in next week...i will revisit then.', '2025-05-26 09:46:10.521', 10605, 195, 64),
(1142, 'stock has moved well', '2025-05-26 09:47:52.667', 10605, 196, 50),
(1147, 'not yet received their order \nfor 5dots', '2025-05-26 09:54:13.258', 10605, 197, 63),
(1151, 'not yet received their order \nfor 5dots', '2025-05-26 09:56:52.471', 10605, 198, 63),
(1155, 'not able to order until next month', '2025-05-26 10:02:04.491', 10605, 199, 62),
(1161, 'Well stocked. we\'ve placed order for two flavors of the sold out products ', '2025-05-26 10:06:43.745', 10605, 200, 21),
(1165, 'They are well stocked ', '2025-05-26 10:07:42.130', 10605, 201, 22),
(1166, 'some products that were ordered were not delivered ', '2025-05-26 10:08:00.693', 10605, 202, 73),
(1168, 'No sales. Low season.', '2025-05-26 10:08:59.963', 10605, 203, 57),
(1169, 'no available, person incharge is not available to place an order', '2025-05-26 10:11:26.476', 10605, 204, 49),
(1174, 'the movement is slow ', '2025-05-26 10:16:34.175', 10605, 205, 39),
(1177, 'out of stock', '2025-05-26 10:17:21.872', 10605, 206, 46),
(1179, 'Had a faulty Blue Razz which they have issued a GRN', '2025-05-26 10:20:51.155', 10605, 207, 23),
(1183, 'mounting display needed at magunas wendani ', '2025-05-26 10:23:02.093', 10605, 208, 63),
(1189, 'no gold pouches order placed on friday', '2025-05-26 10:32:57.264', 10605, 209, 50),
(1195, 'Well Stocked ', '2025-05-26 10:49:12.287', 10605, 210, 21),
(1203, 'placing order next week on Sunday ', '2025-05-26 10:53:21.729', 10605, 211, 63),
(1205, 'They are well stocked ', '2025-05-26 10:54:32.241', 10605, 212, 22),
(1218, 'stock moving slowly', '2025-05-26 11:04:02.973', 10605, 213, 50),
(1219, 'products are well displayed.\nwell stocked too.', '2025-05-26 11:04:20.161', 10605, 214, 64),
(1221, 'The vapes are slow moving.\nHart is the competitor. ', '2025-05-26 11:07:42.359', 10605, 215, 51),
(1228, 'waiting on a reorder', '2025-05-26 11:17:11.081', 10605, 216, 35),
(1229, 'no available products \nplacing an order right now ', '2025-05-26 11:17:29.759', 10605, 217, 49),
(1230, 'The 5 dot are performing better than 3 dots. They will order next month', '2025-05-26 11:17:59.480', 10605, 218, 23),
(1236, 'placed order yesterday', '2025-05-26 11:27:42.415', 10605, 219, 62),
(1240, 'The 9000 puffs are moving slowly.They are to make a reorder for the pouches .5 dot.', '2025-05-26 11:32:06.191', 10605, 220, 51),
(1247, 'Movement is still slow ', '2025-05-26 11:36:37.866', 10605, 221, 30),
(1249, 'placing an order payment terms 70% sales the a check is given ', '2025-05-26 11:38:06.288', 10605, 222, 35),
(1254, 'Hasnt moved yet\nproducts are well stocked and disolayed', '2025-05-26 11:42:47.405', 10605, 223, 64),
(1262, 'hasten on Delivery ', '2025-05-26 11:52:37.976', 10605, 224, 46),
(1265, 'products are alittle slow at the moment \nrrp 2200', '2025-05-26 12:00:09.009', 10605, 225, 49),
(1271, 'This client is very stubborn with paying the pending invoice yet he sold  stocks', '2025-05-26 12:10:00.372', 10605, 226, 23),
(1275, 'product movement realized on 3000 puff\'s ', '2025-05-26 12:22:10.652', 10605, 227, 35),
(1278, 'placed an order last week but yet received', '2025-05-26 12:26:41.909', 10605, 228, 62),
(1279, 'chandarana ridgeway placed order last week but only received 2 flavours they have placed another order', '2025-05-26 12:38:18.773', 10605, 229, 62),
(1280, 'chandarana ridgeway placed order last week but only received 2 flavours they have placed another order', '2025-05-26 12:38:48.054', 10605, 230, 62),
(1286, 'no movement yet \nrrp 3000 puffs 1800\n9000puffs 2200', '2025-05-26 12:52:01.997', 10605, 231, 49),
(1288, 'paid the pending invoice. ', '2025-05-26 12:55:40.219', 10605, 232, 47),
(1289, 'we placed an order for the 5 dot but has not been delivered by Dantra.', '2025-05-26 13:01:18.761', 10605, 233, 23),
(1292, 'Client wants to return 3 dots to exchange with vapes or 5 dots. ', '2025-05-26 13:05:59.444', 10605, 234, 47),
(1299, 'Was to order today but this new manager is still not around. ', '2025-05-26 13:34:27.022', 10605, 235, 47),
(1302, 'well stocked ', '2025-05-26 13:40:12.171', 10605, 236, 46),
(1305, 'meet new supervisor whom I introduced these product to him since are new to him then asked for a display', '2025-05-26 13:46:05.103', 10605, 237, 62),
(1306, 'I made an order of 5dots nicotine pouches on Friday but untill now it has not been delivered ', '2025-05-26 13:54:30.871', 10605, 238, 32),
(1309, 'Trying to Onboard them ', '2025-05-26 14:09:47.063', 10605, 239, 32),
(1322, 'they are complaining of our gold pouches being sold as a pack of 10 instead of 5 like before ', '2025-05-26 15:50:22.784', 10605, 242, 39),
(1330, 'no complains at this outlets\nstill the product is new to more customers', '2025-05-27 06:18:12.542', 10605, 243, 62),
(1333, 'am pushing for 3000 puffs order . ', '2025-05-27 06:25:48.315', 10605, 244, 26),
(1336, 'the products are moving well ', '2025-05-27 06:46:25.044', 10605, 245, 7),
(1338, 'They\'ve been placing the order and it has never been supplied.', '2025-05-27 06:56:17.739', 10605, 246, 21),
(1346, 'The sales are good. we made an order but it has not been delivered. ', '2025-05-27 07:09:37.024', 10605, 247, 73),
(1349, 'They are well stocked ', '2025-05-27 07:12:15.160', 10605, 248, 22),
(1351, 'I have been i having appointments with the owner she’s been promising to place an order but when I visit there is still no stocks', '2025-05-27 07:18:20.784', 10605, 249, 20),
(1352, 'The competitor is the market is elfbar which  has 10000puffs,elfworld which has 12000puffs ,booster pro 20000puffs ,solo bar 16000puffs.\nThere is also velo in the market (6 dot ,17 mg) going ', '2025-05-27 07:20:07.482', 10605, 250, 51),
(1358, 'to place an order today ', '2025-05-27 07:36:08.581', 10605, 251, 7),
(1359, 'All orders to be sent with a representative for arrangements purposes ', '2025-05-27 07:37:40.950', 10605, 252, 30),
(1361, 'products are visible\ncompetition:hart\nmovement:slow', '2025-05-27 07:41:15.635', 10605, 253, 64),
(1362, 'Display received ', '2025-05-27 07:46:19.069', 10605, 254, 20),
(1364, 'They are totally out of stock. They already made an order but has not been delivered ', '2025-05-27 07:51:50.614', 10605, 255, 73),
(1366, 'not stocking out product ', '2025-05-27 07:54:09.765', 10605, 256, 46),
(1370, 'promised to make a reorder of vapes and pouches ', '2025-05-27 07:55:27.460', 10605, 257, 28),
(1372, 'the owner will make a reoder after completion of his new outlet ', '2025-05-27 07:57:13.273', 10605, 258, 50),
(1376, 'Well stocked with Vapes.\nNo stocks for Gold pouches, waiting for delivery.', '2025-05-27 07:58:53.567', 10605, 259, 21),
(1379, 'waiting for the order', '2025-05-27 08:03:08.235', 10605, 260, 48),
(1385, 'promised to make a reorder of vapes and pouches ', '2025-05-27 08:05:40.394', 10605, 261, 28),
(1387, 'good visibility\nwell stocked\n9k puffs pricing @ksh.3000\ncompetition:sky\nmovement:slow', '2025-05-27 08:06:09.902', 10605, 262, 64),
(1389, 'Their order sent on 23rd is yet to be delivered they have zero stocks on pouches', '2025-05-27 08:07:33.566', 10605, 263, 30),
(1390, 'it is a new out we placed orders for both pouches and vapes', '2025-05-27 08:08:05.877', 10605, 264, 31),
(1391, 'will get to me.\ngot discuss with his partner ', '2025-05-27 08:11:40.070', 10605, 265, 46),
(1394, 'order placed', '2025-05-27 08:14:11.228', 10605, 266, 44),
(1401, 'well stocked\nGood visibility\nmovement:slow.', '2025-05-27 08:16:07.479', 10605, 267, 64),
(1403, 'moving slowly but picking up ', '2025-05-27 08:17:47.524', 10605, 268, 63),
(1412, 'placing an order in the course of the day', '2025-05-27 08:23:25.028', 10605, 269, 35),
(1414, 'yet to receive their order for pouches ', '2025-05-27 08:24:20.558', 10605, 270, 31),
(1420, 'They are well stocked ', '2025-05-27 08:27:57.784', 10605, 271, 22),
(1421, 'made an order', '2025-05-27 08:28:09.896', 10605, 272, 48),
(1426, 'well stocked', '2025-05-27 08:35:28.136', 10605, 273, 6),
(1428, 'Hart vape is the competitor. Had made a reorder of the 5 dot and all of them are sold out.They are to reorder next month.\n', '2025-05-27 08:36:22.268', 10605, 274, 51),
(1430, 'stocked ', '2025-05-27 08:36:46.492', 10605, 275, 46),
(1432, 'Following up on their keen interest to try GP.\nSent the catalogue.Theyll make enquiry from manager.', '2025-05-27 08:38:24.105', 10605, 276, 64),
(1433, 'stocked', '2025-05-27 08:39:15.743', 10605, 277, 46),
(1436, 'kuko slaw', '2025-05-27 08:42:29.266', 10605, 278, 48),
(1443, 'to add more 3000 puffs', '2025-05-27 08:51:53.838', 10605, 279, 12),
(1448, 'we are placing another order ', '2025-05-27 08:55:06.505', 10605, 280, 22),
(1454, 'product moving well', '2025-05-27 08:57:53.320', 10605, 281, 46),
(1456, 'still not stocked in GP ', '2025-05-27 08:58:53.275', 10605, 282, 26),
(1459, 'faster moving,will order 5 dots and 9000 puffs next order', '2025-05-27 09:01:34.157', 10605, 283, 62),
(1461, 'waiting for the order', '2025-05-27 09:04:25.212', 10605, 284, 48),
(1464, 'following up on a reorder ', '2025-05-27 09:06:19.893', 10605, 285, 35),
(1466, 'following up on reorder', '2025-05-27 09:06:54.341', 10605, 286, 35),
(1469, 'following up on a reorder', '2025-05-27 09:11:05.511', 10605, 287, 35),
(1477, 'they wanted an order but they have a pending bill ', '2025-05-27 09:20:52.797', 10605, 288, 50),
(1484, 'stock inaingia kesho', '2025-05-27 09:22:42.047', 10605, 289, 48),
(1488, 'not yet stocked ', '2025-05-27 09:23:18.933', 10605, 290, 63),
(1495, 'They are well stocked ', '2025-05-27 09:27:06.557', 10605, 291, 22),
(1497, 'to reorder 3000 puffs\n\n', '2025-05-27 09:30:19.468', 10605, 292, 7),
(1504, 'Awaiting their order... ', '2025-05-27 09:35:57.311', 10605, 293, 30),
(1508, 'needs a display \nhasten on Delivery,  running out of stock', '2025-05-27 09:37:12.541', 10605, 294, 46),
(1513, 'Sky is currently in the market.They are inquiring if pouches are listed they would like to make an order.\nThey have made a reorder of the pouches.', '2025-05-27 09:40:20.562', 10605, 295, 51),
(1514, 'products are moving fast\nassured an order recent', '2025-05-27 09:40:40.663', 10605, 296, 62),
(1517, 'still have Stock for both pouches and vapes', '2025-05-27 09:44:28.829', 10605, 297, 6),
(1521, 'waiting for order', '2025-05-27 09:47:01.364', 10605, 298, 48),
(1534, 'convincing them to stock 3000 puffs', '2025-05-27 10:03:55.664', 10605, 299, 49),
(1536, 'awaiting delivery', '2025-05-27 10:05:26.210', 10605, 300, 46),
(1547, 'The outlet is closed ', '2025-05-27 10:12:37.571', 10605, 301, 20),
(1548, 'asked whether they can get a display so as to act as an advertisement of woosh products since are hidden as it is in whole kiambu', '2025-05-27 10:13:28.065', 10605, 302, 62),
(1561, 'They are well stocked ', '2025-05-27 10:25:14.306', 10605, 303, 22),
(1563, 'stock moving slowly,,they have a pending invoice', '2025-05-27 10:26:55.511', 10605, 304, 50),
(1564, 'They are about to make an order of vapes and pouches ', '2025-05-27 10:30:02.280', 10605, 305, 28),
(1574, 'manager is holding a meeting ,,I will call her on reoder', '2025-05-27 10:38:46.487', 10605, 306, 50),
(1580, 'placing an order for 5dots next week', '2025-05-27 10:41:37.477', 10605, 307, 63),
(1582, 'last pouch was sold yesterday \nstill waiting for the order placed last week', '2025-05-27 10:42:50.195', 10605, 308, 62),
(1584, 'Cooling mint is fast moving having none in the market.\nThe competitor in the market is  booster and hart.\nRecommended our vapes to a customer who ended up buying.', '2025-05-27 10:43:54.226', 10605, 309, 51),
(1588, 'The display should be Mounted ', '2025-05-27 10:53:49.819', 10605, 310, 73),
(1591, 'following up on a possible order. ', '2025-05-27 11:00:10.334', 10605, 311, 35),
(1593, 'They are well stocked ', '2025-05-27 11:01:02.005', 10605, 312, 22),
(1599, 'Vapes are moving very slowly ', '2025-05-27 11:16:29.656', 10605, 313, 28),
(1600, 'Trying to Onboard them ', '2025-05-27 11:39:07.294', 10605, 314, 32),
(1603, 'slow moving product ', '2025-05-27 11:54:10.574', 10605, 315, 46),
(1607, 'outlet has not ordered for strawberry mint... to place next month ', '2025-05-27 11:58:41.148', 10605, 316, 26),
(1611, 'placed another order for 10pcs mixed berry 5 dots ', '2025-05-27 12:13:08.753', 10605, 317, 47),
(1613, 'placed an order ', '2025-05-27 12:16:59.206', 10605, 318, 49),
(1621, 'well stocked', '2025-05-27 12:35:13.180', 10605, 319, 63),
(1624, 'they only have 3 dots remaining.', '2025-05-27 12:39:20.892', 10605, 320, 12),
(1628, '.', '2025-05-27 12:45:27.436', 10605, 321, 12),
(1631, 'They are well stocked for now ', '2025-05-27 12:49:38.916', 10605, 322, 28),
(1636, 'they  made their payment on time ', '2025-05-27 12:53:23.382', 10605, 323, 39),
(1642, 'almost out of stock thus placed an order last week ', '2025-05-27 13:00:27.346', 10605, 324, 7),
(1647, 'order at first of next month', '2025-05-27 13:04:51.090', 10605, 325, 62),
(1650, 'Sky is a competitor in this market.\nHart is the competitor for the vapes.\nThe stock is moving slowly expecially the 3000 puffs', '2025-05-27 13:08:04.668', 10605, 326, 51),
(1654, 'Received their order of 70pcs', '2025-05-27 13:18:38.701', 10605, 327, 57),
(1657, 'They will make their order from S Liquor ', '2025-05-27 13:33:52.995', 10605, 328, 28),
(1658, 'Following up with Edwin and Rajesh on listing and orders', '2025-05-27 13:34:57.212', 10605, 329, 35),
(1660, 'Not yet listed', '2025-05-27 13:35:37.738', 10605, 330, 20),
(1661, 'following up with Rajesh and Edwin on listing and orders ', '2025-05-27 13:35:45.198', 10605, 331, 35),
(1672, 'they will confirm the owner then reach me,,but I will follow up', '2025-05-27 14:04:55.004', 10605, 332, 50),
(1680, 'Waiting to place a cash on order because of previous payment issues which led to my salary deduction to sort the payment. ', '2025-05-27 14:42:45.817', 10605, 333, 35),
(1682, 'Placed an order', '2025-05-27 14:49:53.948', 10605, 334, 30),
(1683, 'Trying to Onboard them ', '2025-05-27 14:51:42.832', 10605, 335, 32),
(1685, 'Trying to Onboard them ', '2025-05-27 14:58:46.208', 10605, 336, 32),
(1690, 'The pouches are moving quickly.They have made a reorder.', '2025-05-27 15:04:35.643', 10605, 337, 51),
(1691, 'to place order for 3000 puffs tomorrow ', '2025-05-27 15:04:37.335', 10605, 338, 26),
(1697, 'they will stock once they have clients', '2025-05-27 15:09:46.771', 10605, 339, 6),
(1713, 'To place an order for vapes tomorrow ', '2025-05-28 07:08:15.655', 10605, 340, 30),
(1715, 'They are currently having stock take', '2025-05-28 07:08:55.166', 10605, 341, 30),
(1718, 'no stocks for 5 dots and 3000 puffs. order to be placed  next month ', '2025-05-28 07:09:46.768', 10605, 342, 26),
(1719, 'They made a reorder ofvour products.\nGogo is a competitor in this maket and sky.', '2025-05-28 07:10:44.427', 10605, 343, 51),
(1727, 'we will do another order next week.', '2025-05-28 07:25:07.822', 10605, 344, 73),
(1738, 'well stocked and displayed.\nBlue razz is moving the most', '2025-05-28 07:41:14.787', 10605, 345, 64),
(1743, 'waiting for pouches ', '2025-05-28 07:43:28.122', 10605, 346, 19),
(1756, 'movement on pouches is good ', '2025-05-28 07:58:54.836', 10605, 347, 31),
(1768, 'will make an order next week', '2025-05-28 08:11:39.786', 10605, 348, 48),
(1771, 'Their display fell down due to vibrations in the building. I will mount another one near the cashier ', '2025-05-28 08:12:03.193', 10605, 349, 23),
(1772, 'trying to onboard them ', '2025-05-28 08:12:08.515', 10605, 350, 18),
(1776, 'Received their returns', '2025-05-28 08:12:50.047', 10605, 351, 57),
(1779, 'in need of display\nshould reorder soon.', '2025-05-28 08:14:50.411', 10605, 352, 64),
(1781, 'The vapes are moving.They requested for a display.The competitor is bullion.', '2025-05-28 08:16:26.892', 10605, 353, 51),
(1785, 'They\'re well stocked ', '2025-05-28 08:21:39.837', 10605, 354, 21),
(1788, 'They are well stocked ', '2025-05-28 08:23:16.283', 10605, 355, 22),
(1790, 'They received their order.', '2025-05-28 08:24:16.156', 10605, 356, 73),
(1797, 'well stocked ', '2025-05-28 08:28:19.563', 10605, 357, 63),
(1799, 'clients are more needing 5dots than 3dots.', '2025-05-28 08:28:33.300', 10605, 358, 17),
(1800, 'They still have stocks for vapes, no order for them at the moment ', '2025-05-28 08:28:40.269', 10605, 359, 30),
(1807, 'products are well moving but the oulet will be closed this week', '2025-05-28 08:32:55.722', 10605, 360, 50),
(1812, 'well stock\npushing for 9k puff now', '2025-05-28 08:35:28.516', 10605, 361, 48),
(1813, 'to place order next week', '2025-05-28 08:35:29.630', 10605, 362, 26),
(1818, 'Received the exchanges', '2025-05-28 08:39:36.448', 10605, 363, 57),
(1820, 'well stocked and displayed.', '2025-05-28 08:40:39.029', 10605, 364, 64),
(1826, 'Received exchanges', '2025-05-28 08:45:09.112', 10605, 365, 57),
(1827, 'Trying to Onboard them ', '2025-05-28 08:45:09.775', 10605, 366, 32),
(1831, 'They are well stocked ', '2025-05-28 08:46:31.749', 10605, 367, 22),
(1832, 'to place an order for distributor ', '2025-05-28 08:46:40.337', 10605, 368, 7),
(1843, 'provide merchandise for client’s buying ', '2025-05-28 08:53:51.580', 10605, 369, 46),
(1848, 'Well stocked. another order will be placed next week ', '2025-05-28 08:56:44.420', 10605, 370, 21),
(1850, 'stock moving slowly especially pouches', '2025-05-28 08:58:11.833', 10605, 371, 50),
(1859, 'to place an order today from baseline ', '2025-05-28 09:05:18.785', 10605, 372, 7),
(1863, 'will place order early next month\n', '2025-05-28 09:06:28.092', 10605, 373, 62),
(1864, 'placing an order on Sunday ', '2025-05-28 09:06:33.890', 10605, 374, 63),
(1867, 'They are well stocked ', '2025-05-28 09:06:55.180', 10605, 375, 22),
(1868, 'Gogo is competitor. \nThey are moving although slowly. ', '2025-05-28 09:09:40.351', 10605, 376, 51),
(1874, 'following up on payments', '2025-05-28 09:15:56.142', 10605, 377, 48),
(1875, 'they are well stocked for now', '2025-05-28 09:16:21.598', 10605, 378, 31),
(1884, 'well displayed and stocked.', '2025-05-28 09:27:09.275', 10605, 379, 64),
(1886, 'the order has been delayed', '2025-05-28 09:27:53.973', 10605, 380, 26),
(1887, 'well stocked and good display.', '2025-05-28 09:28:08.013', 10605, 381, 64),
(1892, 'there\'s a pending order I placed on Monday for the outlet', '2025-05-28 09:30:23.226', 10605, 382, 35),
(1894, 'slow movement of the products\n', '2025-05-28 09:32:15.473', 10605, 383, 50),
(1897, 'They are well stocked ', '2025-05-28 09:33:46.575', 10605, 384, 22),
(1904, 'well stocked ', '2025-05-28 09:42:36.500', 10605, 385, 63),
(1906, 'to place an order ', '2025-05-28 09:43:07.739', 10605, 386, 49),
(1910, 'still not confirmed on stocking ', '2025-05-28 09:48:21.242', 10605, 387, 26),
(1918, 'slow movement, expecting an order ', '2025-05-28 09:54:09.474', 10605, 388, 49),
(1921, 'we are placing order for 9000 puffs tomorrow ', '2025-05-28 09:56:08.014', 10605, 389, 20),
(1927, 'They are well stocked ', '2025-05-28 10:08:10.800', 10605, 390, 22),
(1928, 'New boarding have had a meeting with the manager on our products ', '2025-05-28 10:08:16.618', 10605, 391, 35),
(1929, 'the flavour are good,no complaints about faulty,the store is well stocked', '2025-05-28 10:08:55.434', 10605, 392, 17),
(1945, 'They received their order ', '2025-05-28 10:22:24.287', 10605, 393, 63),
(1949, 'slow moving ', '2025-05-28 10:23:37.855', 10605, 394, 46),
(1954, 'Did a return of the 5dots of sweet Mint 30pcs', '2025-05-28 10:25:37.512', 10605, 395, 73),
(1955, 'engaging management ', '2025-05-28 10:25:40.280', 10605, 396, 49),
(1956, 'gogo and sky are the competitors.', '2025-05-28 10:26:02.784', 10605, 397, 51),
(1961, 'stock is moving slow due to low season in the area', '2025-05-28 10:28:50.807', 10605, 398, 17),
(1966, 'Following up on stocks ', '2025-05-28 10:35:26.936', 10605, 399, 35),
(1971, 'Their order was delayed,I had to get it from the office.', '2025-05-28 10:40:05.939', 10605, 400, 23),
(1973, 'still the fault I confirmed last week not collected', '2025-05-28 10:42:04.490', 10605, 401, 62),
(1979, 'The pouches are moving slowly.\nsky is the competitor.', '2025-05-28 10:48:05.971', 10605, 402, 51),
(1982, 'uplifted 10 pieces of pouches from their main brunch ', '2025-05-28 10:49:14.224', 10605, 403, 49),
(1983, 'Order not received ', '2025-05-28 10:49:22.823', 10605, 404, 47),
(1987, 'stock moving slowly,, order given checklist will be shared on delivery', '2025-05-28 10:51:45.011', 10605, 405, 50),
(1989, 'They received their order ', '2025-05-28 10:52:56.604', 10605, 406, 63),
(1991, 'product moving well', '2025-05-28 10:54:12.880', 10605, 407, 46),
(1993, 'yet to receive their order but they have confirmed that they will receive it today ', '2025-05-28 10:56:49.332', 10605, 408, 31),
(2000, 'They are currently doing their stock takes, hence can not place an order.', '2025-05-28 11:06:26.274', 10605, 409, 23),
(2001, 'pushing for reorder', '2025-05-28 11:06:48.245', 10605, 410, 48),
(2005, 'Pouches don\'t sell at all and the vapes are quite slow at the moment ', '2025-05-28 11:19:10.269', 10605, 411, 49),
(2013, 'delivered pouches personally, movement I fair', '2025-05-28 11:35:55.476', 10605, 412, 49),
(2014, 'awaiting feedback ', '2025-05-28 11:37:37.453', 10605, 413, 46),
(2015, 'a new outlet that have managed to exploit in banana\nhas placed order with dantra this week plz process it', '2025-05-28 11:39:58.422', 10605, 414, 62),
(2021, 'awaiting delivery ', '2025-05-28 11:47:19.916', 10605, 415, 46),
(2024, 'No order until we provide a display for them ', '2025-05-28 11:48:43.074', 10605, 416, 30),
(2026, 'They haven\'t received stocks for 3000puffs but we will place an order start of next month ', '2025-05-28 11:49:51.028', 10605, 417, 21),
(2027, 'to make a reorder', '2025-05-28 11:49:58.356', 10605, 418, 35),
(2028, 'Purchasing manager confirmed that they are still under SoR for our products and can\'t place an order', '2025-05-28 11:54:30.981', 10605, 419, 23),
(2029, 'following up with the manager Dominic on an order. ', '2025-05-28 11:58:30.438', 10605, 420, 35),
(2032, 'delivery came in late ', '2025-05-28 12:04:38.827', 10605, 421, 49),
(2033, 'still pushing for them to make order', '2025-05-28 12:06:39.199', 10605, 422, 48),
(2034, 'they say that they are not willing to do a reoder', '2025-05-28 12:07:29.370', 10605, 423, 50),
(2041, ' Nasim, the owner says that orders will be placed through Titus Finance.', '2025-05-28 12:14:43.507', 10605, 424, 23),
(2044, 'move is quite good', '2025-05-28 12:15:46.138', 10605, 425, 52),
(2047, 'They received their order just the other day', '2025-05-28 12:16:54.327', 10605, 426, 30),
(2049, 'Ordering will be done from 2nd', '2025-05-28 12:18:03.817', 10605, 427, 20),
(2052, 'Placing an order next month for pouches that will be stocked out', '2025-05-28 12:25:43.897', 10605, 428, 23),
(2058, 'have cancelled the exchange due to extra pay from 3 dots to 5 dots but will order next month', '2025-05-28 12:46:26.157', 10605, 429, 62),
(2061, 'placed an order for pouches ', '2025-05-28 12:48:03.771', 10605, 430, 7),
(2063, 'there is reduction in faulties', '2025-05-28 12:55:37.703', 10605, 431, 52),
(2066, 'They have removed the display at the moment as they are repairing the bar area this week. They will place their order next month onwards. Stock controller is aware they have no stocks availab', '2025-05-28 13:10:24.610', 10605, 432, 57),
(2068, 'out of stock awaiting delivery ', '2025-05-28 13:11:43.844', 10605, 433, 46),
(2069, 'out of stock', '2025-05-28 13:12:59.203', 10605, 434, 46),
(2070, 'requested an exchange for the 3 dots with 5 dots since the product is not moving ', '2025-05-28 13:15:45.265', 10605, 435, 23),
(2072, 'well stocked ', '2025-05-28 13:22:41.686', 10605, 436, 7),
(2076, 'Trying to Onboard them ', '2025-05-28 14:02:55.030', 10605, 437, 32),
(2082, 'They want vapes on consignment ', '2025-05-28 14:23:11.512', 10605, 438, 32),
(2085, 'still waiting for their order on 5 dots', '2025-05-28 14:27:48.750', 10605, 439, 62),
(2089, 'stock not moving well,since they just stocked last month', '2025-05-28 14:37:26.276', 10605, 440, 17),
(2099, 'they are out of stock ', '2025-05-28 14:56:08.350', 10605, 441, 34),
(2101, 'Sky is present in the market.They said to go back on next week for an order of pouches.', '2025-05-28 15:07:05.149', 10605, 442, 51),
(2103, 'they have old stocks of 2500puffs', '2025-05-28 15:39:56.587', 10605, 443, 18),
(2109, 'to place an order for 5 dots', '2025-05-29 06:28:24.237', 10605, 444, 7),
(2113, ' pouches are more on demand in this outlet', '2025-05-29 07:06:37.097', 10605, 445, 62),
(2119, 'low on stock \nwill reorder next month', '2025-05-29 07:21:38.634', 10605, 446, 64),
(2120, 'will place an order next week ', '2025-05-29 07:25:15.230', 10605, 447, 18),
(2123, 'The competitor is Gogo .They received their order recently. ', '2025-05-29 07:30:56.495', 10605, 448, 51),
(2134, 'They will make an order on Monday ', '2025-05-29 07:46:27.731', 10605, 449, 73),
(2135, 'They\'re moving the shop to ngong road so no ordering at the moment ', '2025-05-29 07:46:46.451', 10605, 450, 30),
(2136, 'cannot place order untill the previous order is paid', '2025-05-29 07:46:57.788', 10605, 451, 26),
(2140, 'Requesting exchange of 20pcs 3 Dot Pouch for 5 Dot 20pcs', '2025-05-29 07:55:32.505', 10605, 452, 57),
(2142, 'Trying to onboard.', '2025-05-29 07:56:26.875', 10605, 453, 64),
(2147, 'to place an order on monday', '2025-05-29 08:01:14.795', 10605, 454, 17),
(2150, 'kuko slaw\nbut next order atamake mpaka vape', '2025-05-29 08:04:20.749', 10605, 455, 48),
(2154, 'They are well stocked ', '2025-05-29 08:09:22.996', 10605, 456, 22),
(2155, 'stock moving slowly', '2025-05-29 08:09:44.185', 10605, 457, 50),
(2166, 'They had placed an order for 5 dot but never received from Dantra.', '2025-05-29 08:25:36.732', 10605, 458, 23),
(2169, 'stock moving fast but there is demand for 5dots ', '2025-05-29 08:26:20.806', 10605, 459, 73),
(2170, 'Also need for a display ', '2025-05-29 08:26:44.754', 10605, 460, 73),
(2171, 'will place an order early next month', '2025-05-29 08:28:13.675', 10605, 461, 62),
(2174, 'orders will be done from 2nd', '2025-05-29 08:33:56.013', 10605, 462, 20),
(2179, 'well stocked\nwell displayed\nNot interested with GP. will push next week.', '2025-05-29 08:37:46.522', 10605, 463, 64),
(2182, 'They are well stocked ', '2025-05-29 08:40:22.679', 10605, 464, 22),
(2187, 'Delivered flavour exchanges', '2025-05-29 08:49:38.331', 10605, 465, 57),
(2194, 'Doing an order today ', '2025-05-29 08:51:37.138', 10605, 466, 35),
(2198, 'They are well stocked ', '2025-05-29 08:52:14.216', 10605, 467, 22),
(2199, '3dots moving slowly ', '2025-05-29 08:52:39.951', 10605, 468, 63),
(2203, 'no available products, placing an order', '2025-05-29 08:54:40.249', 10605, 469, 49),
(2205, 'low on stock\nwill reorder beginning of coming month', '2025-05-29 08:54:57.716', 10605, 470, 64),
(2206, 'following up on an order.. ', '2025-05-29 08:57:05.926', 10605, 471, 35),
(2212, 'Currently doing stock takes, They will place an order next week.', '2025-05-29 08:59:35.540', 10605, 472, 23),
(2213, 'They have made a reorder of the pouches.', '2025-05-29 09:01:39.261', 10605, 473, 51),
(2214, 'kuko slow\nbut ameuza vape bili za 9 k', '2025-05-29 09:01:39.988', 10605, 474, 48),
(2219, 'They are well stocked with vapes ', '2025-05-29 09:06:33.324', 10605, 475, 19),
(2222, 'stock moving well .they are well stocked ', '2025-05-29 09:07:39.412', 10605, 476, 17),
(2224, 'preparing an order. ', '2025-05-29 09:09:47.193', 10605, 477, 35),
(2225, 'Made a reorder of the pouches .\nHart is the competitor ', '2025-05-29 09:13:54.516', 10605, 478, 51),
(2229, 'kuko slow for now\nbut watu wanaulizia', '2025-05-29 09:18:34.437', 10605, 479, 48),
(2232, 'placing order for pouches ', '2025-05-29 09:20:26.204', 10605, 480, 7),
(2234, 'They are well stocked ', '2025-05-29 09:24:21.198', 10605, 481, 22),
(2236, 'placed an order waiting for delivery ', '2025-05-29 09:25:29.873', 10605, 482, 26),
(2243, 'kuko slow', '2025-05-29 09:29:06.570', 10605, 483, 48),
(2250, 'moving slowly ', '2025-05-29 09:35:53.299', 10605, 484, 63),
(2260, 'Awaiting payment clearance for orders to be placed ', '2025-05-29 09:40:29.542', 10605, 485, 30),
(2261, 'very well stocked', '2025-05-29 09:40:43.011', 10605, 486, 57),
(2265, 'They are well stocked ', '2025-05-29 09:43:35.712', 10605, 487, 22),
(2268, 'Well stocked ', '2025-05-29 09:44:34.644', 10605, 488, 21),
(2270, 'moving well', '2025-05-29 09:45:40.048', 10605, 489, 48),
(2274, 'Movement is good', '2025-05-29 09:49:39.982', 10605, 490, 32),
(2276, 'slow movement, requesting a BA', '2025-05-29 09:51:43.432', 10605, 491, 49),
(2280, 'pending invoice being followed up', '2025-05-29 09:55:17.484', 10605, 492, 50),
(2285, 'zinasonga', '2025-05-29 09:58:35.661', 10605, 493, 48),
(2286, 'to place an order for pouches by the end of this week ', '2025-05-29 09:58:54.075', 10605, 494, 7),
(2287, 'to place an order for pouches by the end of this week ', '2025-05-29 09:59:25.579', 10605, 495, 7),
(2288, 'more demand on 5 dots\nhave unprocessed order placed', '2025-05-29 10:07:48.802', 10605, 496, 62),
(2291, 'There is no stock in naivas HQ. ', '2025-05-29 10:10:48.763', 10605, 497, 47),
(2293, 'The products are fairly new to the market .', '2025-05-29 10:11:52.949', 10605, 498, 51),
(2305, 'They placed an order for the Goldpouches 3 dot and received their order.', '2025-05-29 10:27:28.827', 10605, 499, 23),
(2306, 'to restock next week on Thursday ', '2025-05-29 10:27:51.748', 10605, 500, 7),
(2310, 'Placed an order for 6pcs', '2025-05-29 10:34:07.409', 10605, 501, 30),
(2312, 'Trying to Onboard them ', '2025-05-29 10:36:29.682', 10605, 502, 32),
(2315, 'want a flavour exchange ', '2025-05-29 10:38:30.043', 10605, 503, 49),
(2328, 'well stocked ', '2025-05-29 10:46:43.206', 10605, 504, 63),
(2330, 'well stocked ', '2025-05-29 10:47:52.344', 10605, 505, 7),
(2331, 'They made a reorder of the pouches as they were out of stock.', '2025-05-29 10:48:43.783', 10605, 506, 51),
(2334, 'To get us an order on Friday', '2025-05-29 10:58:20.161', 10605, 507, 35),
(2341, 'They\'re well stocked ', '2025-05-29 11:15:07.272', 10605, 508, 21),
(2343, 'not yet received their order for 5dots\n', '2025-05-29 11:16:06.362', 10605, 509, 63),
(2345, 'The outlet will place an order next month with is since the dealer was already placing through us.', '2025-05-29 11:20:09.328', 10605, 510, 23),
(2350, 'stock moving on well', '2025-05-29 11:24:52.076', 10605, 511, 17),
(2352, 'very slow movement ', '2025-05-29 11:28:40.132', 10605, 512, 49),
(2353, 'Trying to Onboard them,but they prefer another product called Beast ', '2025-05-29 11:28:56.485', 10605, 513, 32),
(2358, 'they received their order ', '2025-05-29 11:34:44.675', 10605, 514, 63),
(2368, 'promised to stock soon from baseline ', '2025-05-29 11:43:38.668', 10605, 515, 7),
(2369, 'The procurement manager has promised to give me an order of the vapes ', '2025-05-29 11:44:25.070', 10605, 516, 32),
(2382, 'They are yet to receive the vapes.', '2025-05-29 11:56:22.360', 10605, 517, 51),
(2384, 'to place an order on 1st june', '2025-05-29 11:57:09.274', 10605, 518, 17),
(2393, 'waiting for their order ', '2025-05-29 12:15:37.085', 10605, 519, 49),
(2394, 'well stocked, following up on payments ', '2025-05-29 12:17:10.306', 10605, 520, 18),
(2396, 'well stocked ', '2025-05-29 12:19:07.262', 10605, 521, 21),
(2400, 'placing their order from next month ', '2025-05-29 12:23:34.636', 10605, 522, 23),
(2409, 'are still waiting our products', '2025-05-29 12:27:59.687', 10605, 523, 62),
(2413, 'well stocked for now ', '2025-05-29 12:32:29.328', 10605, 524, 7),
(2414, 'selling competitor products \nengaging management ', '2025-05-29 12:35:04.469', 10605, 525, 49),
(2419, 'sales are picking and moving ', '2025-05-29 12:54:57.001', 10605, 526, 73),
(2426, 'pending delivery in waiting ', '2025-05-29 13:06:10.206', 10605, 527, 20),
(2434, 'no order will be placed untill the previous order is payed', '2025-05-29 13:26:45.318', 10605, 528, 26),
(2435, 'shared our new catalogue, waiting for an order ', '2025-05-29 13:28:05.784', 10605, 529, 49),
(2437, 'only one piece remaining ', '2025-05-29 13:32:09.078', 10605, 530, 49),
(2445, 'still moving at lower rate', '2025-05-29 13:45:40.328', 10605, 531, 62),
(2453, 'placed their order today,stock is moving well', '2025-05-29 14:03:49.364', 10605, 532, 17),
(2461, 'they have placed an order', '2025-05-29 14:46:07.266', 10605, 533, 50),
(2464, 'They received their order today ', '2025-05-29 14:59:58.582', 10605, 534, 30),
(2467, 'following up on payments ', '2025-05-29 15:10:49.196', 10605, 535, 18);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(2471, 'They have not received vapes yet.Booster and hart are competitors.', '2025-05-29 15:52:15.723', 10605, 536, 51),
(2473, 'we haven’t sold even a single piece', '2025-05-29 16:06:03.607', 10605, 537, 20),
(2498, 'well stocked with vape \nto place an order for pouches next week ', '2025-05-30 06:11:15.966', 10605, 538, 7),
(2505, 'the previous order has not been delivered yet.. a month now\n', '2025-05-30 06:29:32.088', 10605, 539, 26),
(2509, 'to place an order next week ', '2025-05-30 06:32:24.392', 10605, 540, 7),
(2511, 'will place an order early next months', '2025-05-30 06:38:44.654', 10605, 541, 62),
(2516, 'placed their order on pouches', '2025-05-30 06:48:34.624', 10605, 542, 17),
(2524, 'waiting for the order from the office', '2025-05-30 07:22:00.176', 10605, 543, 48),
(2532, 'they will give me a call once they decide to stock. ', '2025-05-30 07:30:42.965', 10605, 544, 6),
(2534, 'well stocked, still waiting for the 5Dots Pouches stocks to be delivered.', '2025-05-30 07:31:59.018', 10605, 545, 21),
(2535, 'They made a reorder .They are moving slowly expecially 9000puffs.', '2025-05-30 07:35:21.117', 10605, 546, 51),
(2536, 'waiting for the order', '2025-05-30 07:35:47.115', 10605, 547, 48),
(2540, 'will place an order next week ', '2025-05-30 07:48:37.044', 10605, 548, 18),
(2545, 'will place an order next month', '2025-05-30 08:06:03.468', 10605, 549, 62),
(2549, 'will place an order ', '2025-05-30 08:09:49.630', 10605, 550, 18),
(2550, 'low on vapes\nBut theyve already requested from their hq for a top up.', '2025-05-30 08:09:59.481', 10605, 551, 64),
(2551, 'we are out of stocks on pouches waiting for delivery ', '2025-05-30 08:10:02.731', 10605, 552, 20),
(2552, 'Trying to Onboard.the owner will place order on pouches next month ', '2025-05-30 08:15:10.080', 10605, 553, 32),
(2562, 'stocks in order', '2025-05-30 08:26:21.344', 10605, 554, 35),
(2574, 'so far they have only sold one ', '2025-05-30 08:37:45.022', 10605, 555, 12),
(2575, 'products are average moving', '2025-05-30 08:37:53.687', 10605, 556, 50),
(2576, 'The vapes are moving slowly especially 9000puffs.The competitor is sky.', '2025-05-30 08:37:55.955', 10605, 557, 51),
(2578, 'They submitted their sales report for the B2C program. They finally made a sale', '2025-05-30 08:40:13.359', 10605, 558, 23),
(2581, 'we placed an order but has not been delivered ', '2025-05-30 08:43:59.703', 10605, 559, 73),
(2582, 'low on 9k puffs\nwaiting for response from hq for permission to order directly\n', '2025-05-30 08:45:53.209', 10605, 560, 64),
(2583, 'new onboarding \nplaced an order of 10 PCs for start and 25 PCs of pouches ', '2025-05-30 08:49:11.577', 10605, 561, 7),
(2588, 'They are well stocked ', '2025-05-30 08:59:34.271', 10605, 562, 22),
(2589, 'following up on payments ', '2025-05-30 08:59:52.041', 10605, 563, 18),
(2593, 'They are closed in order placing until 1st June.', '2025-05-30 09:07:36.479', 10605, 564, 23),
(2596, 'Pending order from HQ', '2025-05-30 09:11:02.899', 10605, 565, 35),
(2602, 'cannot stock 3000 puffs', '2025-05-30 09:16:26.735', 10605, 566, 26),
(2603, 'to place an order now', '2025-05-30 09:17:30.728', 10605, 567, 7),
(2604, 'Trying to Onboard them,they want vapes on consignment ', '2025-05-30 09:17:56.843', 10605, 568, 32),
(2605, 'The sweet mint is moving slowly.They will made a reorder  by next week.', '2025-05-30 09:18:07.160', 10605, 569, 51),
(2609, 'not yet received their order for 5dots', '2025-05-30 09:20:39.788', 10605, 570, 63),
(2616, 'we\'ll make an order for vapes next week. there is also a need for a display ', '2025-05-30 09:31:07.735', 10605, 571, 73),
(2622, 'well stocked ', '2025-05-30 09:36:08.734', 10605, 572, 7),
(2628, 'Ordering next week. ', '2025-05-30 09:39:37.784', 10605, 573, 35),
(2632, 'moving very fast order was placed yesterday', '2025-05-30 09:45:58.114', 10605, 574, 62),
(2635, 'Movement picking ok', '2025-05-30 09:50:46.374', 10605, 575, 30),
(2638, 'order not received', '2025-05-30 09:55:14.431', 10605, 576, 50),
(2641, 'There was a return for Total Kisii of 9pcs 3 dots for an exchange. they haven\'t received it yet', '2025-05-30 09:58:58.436', 10605, 577, 35),
(2642, 'not yet stocked', '2025-05-30 09:59:09.048', 10605, 578, 63),
(2647, 'Following up on payments', '2025-05-30 10:06:52.068', 10605, 579, 57),
(2650, 'Following up on payments ', '2025-05-30 10:09:01.087', 10605, 580, 57),
(2654, 'They are well stocked ', '2025-05-30 10:13:32.388', 10605, 581, 22),
(2659, 'They received their order of pouches.', '2025-05-30 10:25:05.975', 10605, 582, 51),
(2665, 'They don\'t have stocks ', '2025-05-30 10:30:01.628', 10605, 583, 22),
(2669, 'vapes moving slowly but picking up ', '2025-05-30 10:35:25.691', 10605, 584, 63),
(2671, 'will place order beggining of the month', '2025-05-30 10:37:42.237', 10605, 585, 64),
(2677, 'ptoducts are doing well', '2025-05-30 10:41:41.234', 10605, 586, 50),
(2679, 'To place an order next month ', '2025-05-30 10:41:56.891', 10605, 587, 23),
(2680, 'They will make a reorder by next week. ', '2025-05-30 10:43:30.139', 10605, 588, 51),
(2685, 'They received their order ', '2025-05-30 10:45:21.190', 10605, 589, 30),
(2688, 'will place an order next week ', '2025-05-30 10:48:07.116', 10605, 590, 18),
(2693, 'No sales due to low season', '2025-05-30 10:52:45.073', 10605, 591, 57),
(2698, 'No product movement. Will not be placing their order any time soon. ', '2025-05-30 11:03:27.061', 10605, 592, 57),
(2702, 'stocked 60 pieces 3k puffs\n48 pieces non-rechargable. well stocked.\nmovement:slow.', '2025-05-30 11:16:14.712', 10605, 593, 64),
(2704, 'Client has sold our product yet he doesn\'t want to pay', '2025-05-30 11:16:33.141', 10605, 594, 23),
(2706, 'checking for reorders', '2025-05-30 11:21:09.967', 10605, 595, 35),
(2710, 'They are well stocked ', '2025-05-30 11:25:14.988', 10605, 596, 22),
(2717, 'well stocked ', '2025-05-30 11:29:07.301', 10605, 597, 7),
(2718, 'to place order for GP on 2nd june', '2025-05-30 11:29:51.831', 10605, 598, 26),
(2721, 'well stocked for now \n', '2025-05-30 11:32:44.057', 10605, 599, 7),
(2724, 'mounting needed at magunas wendani ', '2025-05-30 11:38:30.652', 10605, 600, 63),
(2730, 'stocked In 9000 puffs and 3000 puffs . pending delivery for gp ', '2025-05-30 11:46:27.761', 10605, 601, 26),
(2733, 'order to be given for start up', '2025-05-30 11:50:49.687', 10605, 602, 44),
(2735, 'wait until next month for next order', '2025-05-30 11:51:17.004', 10605, 603, 62),
(2736, 'Items movement is stagnant ', '2025-05-30 11:51:26.251', 10605, 604, 30),
(2737, 'They have not received their order from Dantra', '2025-05-30 12:00:48.275', 10605, 605, 23),
(2740, 'well stocked\nwell displayed\nmovement is slow\nno competition yet...Trying to get them to order GP.', '2025-05-30 12:05:33.904', 10605, 606, 64),
(2747, 'stock are picking but there is a need for a proper display ', '2025-05-30 12:23:38.589', 10605, 607, 73),
(2752, 'trying to onboard them ', '2025-05-30 12:34:28.624', 10605, 608, 18),
(2756, 'waiting for the stock', '2025-05-30 12:37:41.331', 10605, 609, 48),
(2761, 'ziko slaw\nthey will not reorder\nata zingine zilitumwa diani', '2025-05-30 12:47:24.949', 10605, 610, 48),
(2764, '.', '2025-05-30 12:54:09.710', 10605, 611, 12),
(2767, '2pcs 2500puffs to be returned ', '2025-05-30 12:58:03.756', 10605, 612, 30),
(2770, 'manager has requested that the order placed last week to be postponed until next week since they are closing on stocks tomorrow until next week', '2025-05-30 13:01:15.704', 10605, 613, 62),
(2774, 'pushing for reorder za 3 k puff\nna pouches', '2025-05-30 13:09:21.440', 10605, 614, 48),
(2777, 'well stocked following up on payments ', '2025-05-30 13:26:12.999', 10605, 615, 18),
(2779, 'Trying to Onboard them ', '2025-05-30 13:48:31.628', 10605, 616, 32),
(2782, '.', '2025-05-30 14:28:06.748', 10605, 617, 12),
(2784, 'out of stock ', '2025-05-30 14:38:35.105', 10605, 618, 6),
(2786, 'We placed a small order for 10pcs ', '2025-05-30 14:49:06.851', 10605, 619, 30),
(2789, 'na', '2025-05-30 15:00:27.855', 10605, 620, 12),
(2790, '3000 puffs is doing well compared to 9000 puffs', '2025-05-30 15:03:17.948', 10605, 621, 20),
(2794, 'I sent Dantra to this client she insisted to be sold to by Dantra', '2025-05-30 15:22:24.202', 10605, 622, 20),
(2796, 'waiting for delivery ', '2025-05-30 15:43:09.341', 10605, 623, 20),
(2797, 'The 9000 puffs are moving quit slowly. ', '2025-05-30 15:43:40.095', 10605, 624, 51),
(2800, 'Most items requested were not delivered ', '2025-05-31 07:04:56.471', 10605, 625, 30),
(2803, 'received their stock and they are moving well ', '2025-05-31 07:18:18.654', 10605, 626, 7),
(2807, 'They received 9000puffs vapes.The 3000 puffs are moving quickly.', '2025-05-31 07:56:38.966', 10605, 627, 51),
(2810, 'uplifted 15pcs from baseline ', '2025-05-31 08:02:37.649', 10605, 628, 7),
(2814, 'will place order at first next month', '2025-05-31 08:12:36.429', 10605, 629, 62),
(2815, 'They don\'t sell nicotine products, they tried once and it never did well soon nice the outlet has no traffic.', '2025-05-31 08:12:47.006', 10605, 630, 23),
(2818, 'They are well stocked ', '2025-05-31 08:14:23.415', 10605, 631, 22),
(2820, 'talked to Edwin on listing which is still pending ', '2025-05-31 08:17:44.928', 10605, 632, 35),
(2821, 'They are closed over issues with public health to follow up tomorrow, there was a possible order to place', '2025-05-31 08:22:43.276', 10605, 633, 35),
(2827, 'They\'ve not recieved 3000puffs yet ', '2025-05-31 08:27:10.263', 10605, 634, 21),
(2831, 'Movement is abit aslow will place an order next week ', '2025-05-31 08:28:26.418', 10605, 635, 30),
(2833, 'The made a reorder of the pouches. The pouches are moving quickly. ', '2025-05-31 08:30:03.035', 10605, 636, 51),
(2834, 'They are don\'t have no stocks ', '2025-05-31 08:30:10.830', 10605, 637, 22),
(2840, 'They promise to place an order next week ', '2025-05-31 08:40:31.666', 10605, 638, 22),
(2843, 'New visit, the outlet has no enjoy shop.', '2025-05-31 08:46:36.817', 10605, 639, 23),
(2844, 'well displayed and stocked.\nmovement:moving fine', '2025-05-31 08:47:19.342', 10605, 640, 64),
(2847, 'The outlet is Muslim operated and can not stock our products.', '2025-05-31 08:53:20.106', 10605, 641, 23),
(2848, 'will place order starting next month', '2025-05-31 09:01:51.829', 10605, 642, 62),
(2849, 'Waiti', '2025-05-31 09:05:19.860', 10605, 643, 35),
(2850, 'Pending order, checked in for order', '2025-05-31 09:06:51.124', 10605, 644, 35),
(2852, 'mixed berry had Started selling well. ', '2025-05-31 09:13:22.149', 10605, 645, 47),
(2855, 'They\'re awaiting delivery from dantra', '2025-05-31 09:15:50.943', 10605, 646, 30),
(2860, 'well stocked. \nwe will place order for the sold out flavors next week ', '2025-05-31 09:22:17.689', 10605, 647, 21),
(2861, 'They are running out of stock ', '2025-05-31 09:22:22.960', 10605, 648, 28),
(2864, 'well stocked with 9000 puffs\nrrp 2000/=\nmovement:slow', '2025-05-31 09:35:10.566', 10605, 649, 64),
(2867, 'received 69ocs gold poaches ', '2025-05-31 09:47:02.711', 10605, 650, 47),
(2869, 'Received 60pcs gold pouches. ', '2025-05-31 09:47:25.476', 10605, 651, 47),
(2870, 'well stocked ', '2025-05-31 09:47:28.051', 10605, 652, 63),
(2874, 'No sales during low season. ', '2025-05-31 09:52:56.561', 10605, 653, 57),
(2875, 'found them closed, had a previous order of 5dots making follow up', '2025-05-31 09:58:04.088', 10605, 654, 35),
(2878, 'placed and received their order,stock is moving well', '2025-05-31 10:03:27.290', 10605, 655, 17),
(2883, 'No order has been delivered since last month even after successful order placement ', '2025-05-31 10:16:24.556', 10605, 656, 26),
(2888, 'not yet received their order ', '2025-05-31 10:19:21.538', 10605, 657, 63),
(2893, 'They received their order ', '2025-05-31 10:32:47.077', 10605, 658, 63),
(2895, 'No sales affecting payment period. ', '2025-05-31 10:34:41.478', 10605, 659, 57),
(2898, 'stock moving slowly', '2025-05-31 10:49:05.948', 10605, 660, 50),
(2900, 'Well stocked ', '2025-05-31 10:52:32.101', 10605, 661, 57),
(2903, 'well displayed and stocked.\nslow movement...rrp 2000/= for 9000 puffs\nrrp 1570/= for 3000 puffs.\n\n', '2025-05-31 11:20:20.917', 10605, 662, 64),
(2907, 'naivas umoja very stocked', '2025-05-31 11:31:20.792', 10605, 663, 26),
(2911, 'No stocks for 3000puffs bbut', '2025-05-31 12:08:06.498', 10605, 664, 21),
(2912, 'no stocks for 3000puffs since they\'re selling under the counter but planning for an order next month ', '2025-05-31 12:08:52.162', 10605, 665, 21),
(2917, '9000 puffs doing so well compared to 3000 puffs', '2025-05-31 12:50:42.546', 10605, 666, 26),
(2920, 'no delivery has been made since last month even after order placement ', '2025-05-31 13:03:52.413', 10605, 667, 26),
(2922, 'to place an order next week ', '2025-05-31 13:12:19.038', 10605, 668, 17),
(2923, 'Trying to Onboard them ', '2025-05-31 13:22:27.216', 10605, 669, 32),
(2931, 'They\'re well stocked ', '2025-06-03 05:34:06.479', 10605, 671, 21),
(2934, 'They\'re well stocked up with Vapes. The Gold pouches have not been delivered yet ', '2025-06-03 05:48:05.725', 10605, 672, 21),
(2936, 'cool mint 5 dots doing well ', '2025-06-03 06:10:42.742', 10605, 673, 26),
(2938, 'They\'ve not displayed out products neither the compety', '2025-06-03 06:20:56.951', 10605, 674, 21),
(2939, 'They\'ve not displayed our products neither the competitors. Order from their management ', '2025-06-03 06:21:57.679', 10605, 675, 21),
(2943, 'they have received their order with a pouches display which is compatible to use since once the pouch is inserted it is hard to remove', '2025-06-03 06:49:29.818', 10605, 676, 62),
(2945, 'to place an order soon', '2025-06-03 06:54:22.139', 10605, 677, 12),
(2948, 'our products are selling under the counters they were told to remove them by the hq', '2025-06-03 07:10:17.486', 10605, 678, 20),
(2954, 'Products aré moving very fast ', '2025-06-03 07:17:54.675', 10605, 679, 73),
(2956, 'They are requesting for some samples for their customers ', '2025-06-03 07:19:04.994', 10605, 680, 73),
(2957, 'well stocked and the product is moving well ', '2025-06-03 07:19:35.157', 10605, 681, 7),
(2960, 'They are well stocked ', '2025-06-03 07:24:49.027', 10605, 682, 22),
(2964, 'will place there order ', '2025-06-03 07:36:10.770', 10605, 683, 18),
(2967, 'They are well stocked ', '2025-06-03 07:39:03.391', 10605, 684, 22),
(2968, 'have enough stock', '2025-06-03 07:40:20.851', 10605, 685, 62),
(2972, 'They still have stocks we wait for them to push a bit', '2025-06-03 07:47:08.166', 10605, 686, 30),
(2977, 'We\'ll make an order tomorrow ', '2025-06-03 07:50:30.359', 10605, 687, 73),
(2980, 'well stocked with the 3k puffs and 5dots', '2025-06-03 07:51:50.396', 10605, 688, 63),
(2984, 'the movement is very slow', '2025-06-03 07:58:27.312', 10605, 689, 39),
(2987, 'Trying to Onboard them ', '2025-06-03 08:02:25.319', 10605, 690, 32),
(2988, 'Following up a possible order', '2025-06-03 08:03:28.770', 10605, 691, 35),
(2996, 'placing an order today ', '2025-06-03 08:09:42.923', 10605, 692, 35),
(2997, 'still well stocked to place order when stock lasts', '2025-06-03 08:09:53.065', 10605, 693, 17),
(3003, 'they want an exchange in pouches', '2025-06-03 08:12:46.245', 10605, 694, 39),
(3008, 'They will place their order today for the pouches ', '2025-06-03 08:18:01.419', 10605, 695, 51),
(3014, 'the movement is okay ', '2025-06-03 08:19:15.115', 10605, 696, 39),
(3015, 'stock moving too slowly', '2025-06-03 08:19:52.705', 10605, 697, 50),
(3017, 'low on stock...\nFollowing to ensure we place an order...', '2025-06-03 08:21:11.069', 10605, 698, 64),
(3021, 'expecting a reorder ', '2025-06-03 08:26:00.422', 10605, 699, 39),
(3025, 'The purchasing manager has given feedback that he has not received formal communication till now in regard to them being removed from SoR.', '2025-06-03 08:30:16.586', 10605, 700, 23),
(3028, 'the movement is okay ', '2025-06-03 08:31:34.374', 10605, 701, 39),
(3031, 'Trying to onboard...manager is out of country\nTold to revisit again.', '2025-06-03 08:36:15.591', 10605, 702, 64),
(3034, 'new client ordered 5 pieces for a start ', '2025-06-03 08:37:14.173', 10605, 703, 7),
(3035, 'They already made an order yesterday ', '2025-06-03 08:37:27.294', 10605, 704, 73),
(3037, 'The owner is yet to place an order through Titus From Finance. She needed 5 dots.', '2025-06-03 08:38:57.735', 10605, 705, 23),
(3039, 'The sweet mint are moving slowly compared to the cooling mint.\ngold pouch rrp 550.\nThe competitor is booster.', '2025-06-03 08:41:10.395', 10605, 706, 51),
(3040, 'will order pouches this week', '2025-06-03 08:44:30.025', 10605, 707, 32),
(3045, 'zinasonga', '2025-06-03 08:49:48.066', 10605, 708, 48),
(3047, 'placed an order from distributor of 6 PCs to be delivered tomorrow ', '2025-06-03 08:50:50.385', 10605, 709, 7),
(3054, 'placing an order for the 5 dot and share lpo on email', '2025-06-03 09:06:24.901', 10605, 710, 23),
(3055, 'the manager hataki kuchukua stock', '2025-06-03 09:06:36.193', 10605, 711, 48),
(3060, 'waiting for order', '2025-06-03 09:18:36.054', 10605, 712, 48),
(3061, 'well stocked to place an order of pouches this week', '2025-06-03 09:22:34.499', 10605, 713, 17),
(3070, 'competitors are robust and innobar', '2025-06-03 10:04:03.013', 10605, 714, 50),
(3072, 'made an order', '2025-06-03 10:04:47.637', 10605, 715, 48),
(3073, 'The outlet do not have any of our product. We\'ve made an order today.', '2025-06-03 10:10:03.616', 10605, 716, 73),
(3077, 'didn\'t make to have a conversation with the shop attendent \ndue to stock taking', '2025-06-03 10:18:51.230', 10605, 717, 48),
(3081, 'The new manager hasn\'t agreed on stocking. he\'s taking me back and forth. ', '2025-06-03 10:27:41.945', 10605, 718, 47),
(3082, 'pushing for an order of vapes,but they are hesitant to stock ', '2025-06-03 10:32:15.812', 10605, 719, 32),
(3083, 'Naivas hyper Kisii has placed an order of 80 vapes both 9k and 3k puffs', '2025-06-03 10:37:51.677', 10605, 720, 35),
(3086, 'still following up on the management to place an order. ', '2025-06-03 10:46:22.725', 10605, 721, 35),
(3094, 'Naivas Kisii CBD to make a reoder of the 3000 puffs ', '2025-06-03 11:35:18.720', 10605, 722, 35),
(3113, 'Follow-up we see if the manager will give as order ', '2025-06-03 12:49:45.484', 10605, 723, 40),
(3115, 'she is not finically stable at now ', '2025-06-03 13:02:50.595', 10605, 724, 40),
(3121, 'Very slow product movement', '2025-06-03 13:21:11.326', 10605, 725, 57),
(3124, 'products are moving slowly with low season ', '2025-06-03 13:45:02.534', 10605, 726, 57),
(3125, 'Trying to Onboard them ', '2025-06-03 13:50:56.845', 10605, 727, 32),
(3128, 'pouches are moving quickly. The vapes are slow moving', '2025-06-03 14:08:15.760', 10605, 728, 51),
(3130, 'well stocked to place their order next week', '2025-06-03 14:12:31.704', 10605, 729, 57),
(3131, 'Trying to Onboard them ', '2025-06-03 14:44:58.576', 10605, 730, 32),
(3135, 'Following up on payments ', '2025-06-03 14:54:53.955', 10605, 731, 57),
(3137, 'Following up on payments. Products are not selling at all.', '2025-06-03 14:58:56.732', 10605, 732, 57),
(3146, 'to place an order for 3000 puffs', '2025-06-04 06:54:45.286', 10605, 733, 7),
(3149, 'sky ,booster and hart are competitors.\nbooster rrp 820\nsky rrp is 690\nhart recharge rrp 2170\nnon recharge rrp 1470\nThe cooling mint 5 dot is moving faster.', '2025-06-04 07:24:24.080', 10605, 734, 51),
(3160, 'no delivery yet for the last 40 days', '2025-06-04 07:40:31.238', 10605, 735, 26),
(3162, 'stock has been moving slow due to low season ', '2025-06-04 07:40:56.235', 10605, 736, 17),
(3165, 'well displayed\nrrp 9k 2000\nrrp 3k 1700\ncompetitor:none', '2025-06-04 07:45:37.564', 10605, 737, 64),
(3169, 'stock moving well', '2025-06-04 07:52:55.594', 10605, 738, 50),
(3173, 'well stocked\nwell displayed.\n\nrrp 9k 3000/=\nrrp 3k 2300/=\n\ncompetition :sky\nBut GP is moving than competition.\nVapes not moving...price relatively high compared to shell which is close.', '2025-06-04 08:02:54.182', 10605, 739, 64),
(3175, 'They already made an order yesterday. ', '2025-06-04 08:10:49.807', 10605, 740, 73),
(3179, 'They got  6 pieces from rubis koinange street.\nThe pouches are moving quickly.', '2025-06-04 08:20:30.181', 10605, 741, 51),
(3187, 'slow selling no display', '2025-06-04 08:24:02.072', 10605, 742, 50),
(3188, 'Awaiting delivery ', '2025-06-04 08:24:09.678', 10605, 743, 30),
(3189, 'low on stock\nwill place order.', '2025-06-04 08:24:09.918', 10605, 744, 64),
(3196, 'the order has not receive', '2025-06-04 08:39:00.411', 10605, 745, 48),
(3199, 'They\'re still selling under the counter hence making the sales low ', '2025-06-04 08:41:10.768', 10605, 746, 21),
(3203, 'They have not received their order for 5 dota', '2025-06-04 08:48:48.331', 10605, 747, 23),
(3204, 'They have not received their order for 5 dota', '2025-06-04 08:49:07.012', 10605, 748, 23),
(3205, 'They have not received their order for 5 dots ', '2025-06-04 08:49:13.276', 10605, 749, 23),
(3206, 'Low sale turn out', '2025-06-04 08:50:24.654', 10605, 750, 35),
(3210, 'gaining the market ', '2025-06-04 08:54:08.668', 10605, 751, 46),
(3215, 'well displayed\nlow on stock \n3k rrp 1900\n\nordering today.', '2025-06-04 09:04:25.550', 10605, 752, 64),
(3219, 'Well stocked and they\'re selling under the counter too. \nwe\'ve placed order for the sold out products ', '2025-06-04 09:06:19.692', 10605, 753, 21),
(3223, 'The movements is very low \nbecause it\'s still new the customers ', '2025-06-04 09:10:10.991', 10605, 754, 22),
(3224, 'Still reluctant to pick more stocks', '2025-06-04 09:10:14.742', 10605, 755, 30),
(3227, 'low on stock\nplacing order today', '2025-06-04 09:11:41.838', 10605, 756, 64),
(3232, 'product moving well', '2025-06-04 09:14:12.310', 10605, 757, 46),
(3235, 'placed an order still waiting from dispatch ', '2025-06-04 09:15:33.536', 10605, 758, 35),
(3236, 'They have not received their order for 5dots', '2025-06-04 09:16:04.289', 10605, 759, 63),
(3239, 'waiting for the order\nbut price za pouches ziko juu', '2025-06-04 09:17:43.686', 10605, 760, 48),
(3242, 'still closed we were to place an order on pouches. to make follow up', '2025-06-04 09:33:05.094', 10605, 761, 35),
(3244, 'The pouches are moving slowly .\nsky is the competitor rrp 540', '2025-06-04 09:36:44.643', 10605, 762, 51),
(3248, 'They are well stocked ', '2025-06-04 09:42:18.411', 10605, 763, 22),
(3252, 'moving slowly ', '2025-06-04 09:46:48.085', 10605, 764, 63),
(3257, 'They are well stocked.', '2025-06-04 09:52:15.295', 10605, 765, 23),
(3259, 'They\'re well stocked but selling under the counter ', '2025-06-04 09:53:27.171', 10605, 766, 21),
(3262, 'Business is quite low though they have stocks but no 5dots available they will not be ordering in the meantime ', '2025-06-04 09:57:35.355', 10605, 767, 30),
(3267, 'They place order today ', '2025-06-04 10:03:49.719', 10605, 768, 22),
(3268, 'They place order today ', '2025-06-04 10:06:20.830', 10605, 769, 22),
(3270, 'slow movement of products', '2025-06-04 10:07:26.786', 10605, 770, 91),
(3272, 'vapes are slow moving more so the 9000 puffs', '2025-06-04 10:08:20.532', 10605, 771, 20),
(3277, 'Placing an order ', '2025-06-04 10:17:44.617', 10605, 772, 35),
(3282, 'Need for a display ', '2025-06-04 10:19:40.432', 10605, 773, 73),
(3283, 'They movement is very low since it\'s new on the market ', '2025-06-04 10:19:43.498', 10605, 774, 22),
(3284, 'The 3000 puffs are moving quickly.\ncompetitor is gogo.\ngogo 10000puffs rrp 2500\ngogo 16000puffs rrp 3300.\n', '2025-06-04 10:20:06.689', 10605, 775, 51),
(3289, 'awaiting the director for a re order', '2025-06-04 10:26:00.674', 10605, 776, 46),
(3292, 'The supervisor requested I come for the order tomorrow since she is overwhelmed (she is handling receiving and customers alone today)', '2025-06-04 10:33:47.044', 10605, 777, 23),
(3296, 'They movement are now moving ', '2025-06-04 10:35:57.577', 10605, 778, 22),
(3300, 'awaiting delivery ', '2025-06-04 10:43:23.673', 10605, 779, 46),
(3307, 'no delivery has been done even after successful order placement ', '2025-06-04 10:46:06.318', 10605, 780, 26),
(3317, 'They will place another order for the 5 dot since 3 dot is not selling. their RRP is high i.e 3000 puffs, ksh 2300  and the G.P is Ksh 650', '2025-06-04 10:58:06.649', 10605, 781, 23),
(3320, 'There are no competitors stocks as of 4/6/2025.The competitors in the market is bullion.\nTaking that its their first order the products are moving well.', '2025-06-04 10:59:16.115', 10605, 782, 51),
(3325, 'out of stock.\nawaiting delivery. ', '2025-06-04 11:03:20.417', 10605, 783, 46),
(3328, '9000 puffs moving', '2025-06-04 11:05:23.163', 10605, 784, 50),
(3329, 'have ordered pouches since last week and yet received ', '2025-06-04 11:06:21.178', 10605, 785, 62),
(3332, 'well stocked ', '2025-06-04 11:08:47.491', 10605, 786, 7),
(3336, 'moving slowly ', '2025-06-04 11:12:25.540', 10605, 787, 63),
(3341, 'They are well stocked ', '2025-06-04 11:21:14.472', 10605, 788, 22),
(3345, 'They could not make an order because the  owner is not around and she issues the cheques hence could not make the order.', '2025-06-04 11:24:17.081', 10605, 789, 51),
(3349, 'Need for a display in this outlet ', '2025-06-04 11:25:01.221', 10605, 790, 73),
(3351, 'we have a pending order for 9000 puffs', '2025-06-04 11:30:21.799', 10605, 791, 20),
(3358, 'slow moving product ', '2025-06-04 11:34:16.972', 10605, 792, 46),
(3360, 'customers mostly visits on weekends and buy on weekends', '2025-06-04 11:35:56.450', 10605, 793, 48),
(3371, 'sweet mint\nna citrus ndo zimetulia for now', '2025-06-04 11:50:32.365', 10605, 794, 48),
(3372, 'well stocked ', '2025-06-04 11:50:55.950', 10605, 795, 63),
(3374, 'Gogo is the competitor .\n16000puffs for gogo goes for 3400\nwoosh 3000puffs are moving quickly. ', '2025-06-04 11:59:31.609', 10605, 796, 51),
(3375, 'Follow-up for order on Friday ', '2025-06-04 11:59:45.811', 10605, 797, 40),
(3376, 'Follow-up on Friday for the order ', '2025-06-04 12:01:03.406', 10605, 798, 40),
(3379, 'placed order yesterday ', '2025-06-04 12:05:11.248', 10605, 799, 62),
(3381, 'waiting for feedback this week ', '2025-06-04 12:07:11.053', 10605, 800, 40),
(3387, 'well stocked ', '2025-06-04 12:10:25.832', 10605, 801, 63),
(3388, 'they have a competitor in their shop that is hart company\nclients need 9000pyffs more than 3000puffs because of it\'s strong flavour', '2025-06-04 12:12:33.139', 10605, 802, 17),
(3392, 'out of stock', '2025-06-04 12:14:29.292', 10605, 803, 46),
(3393, 'we only listed 9000 puffs so far 1pc sold they are not will to list 3000 or pouches ', '2025-06-04 12:14:41.700', 10605, 804, 20),
(3396, 'the outlet is very stocked with both 9000 and 3000 puffs', '2025-06-04 12:20:17.674', 10605, 805, 26),
(3397, 'shared our catalogue waiting for the feedback from owner ', '2025-06-04 12:22:22.374', 10605, 806, 40),
(3401, 'They need an exchange for the 3 dots that they currently have with 5 dots ', '2025-06-04 12:28:22.125', 10605, 807, 23),
(3403, 'Follow-up for order ', '2025-06-04 12:36:36.943', 10605, 808, 40),
(3406, 'tlno competitor products.\n\nto pay the pending invoice. ', '2025-06-04 12:43:57.432', 10605, 809, 47),
(3409, 'Low season is affecting sales.', '2025-06-04 12:46:49.808', 10605, 810, 57),
(3412, 'to restock when the students report back', '2025-06-04 13:03:50.552', 10605, 811, 44),
(3416, 'they received the stock.no competitor products. ', '2025-06-04 13:12:24.841', 10605, 812, 47),
(3418, 'Vapes are moving slowly. Pouches sales have improved. ', '2025-06-04 13:14:49.025', 10605, 813, 57),
(3420, 'Movement of vapes is very slowly ', '2025-06-04 13:16:31.642', 10605, 814, 28),
(3427, 'their network is not available,to reorder.', '2025-06-04 13:41:04.005', 10605, 815, 44),
(3428, 'Following up on payments ', '2025-06-04 13:42:35.621', 10605, 816, 57),
(3434, 'They are doing stock take ', '2025-06-04 14:01:15.232', 10605, 817, 30),
(3436, 'On going stock take no order', '2025-06-04 14:07:57.280', 10605, 818, 30),
(3438, 'They are planning to do a reoder of vapes ', '2025-06-04 14:12:23.792', 10605, 819, 28),
(3444, 'Awaiting their exchange to complete payments.', '2025-06-04 14:33:38.068', 10605, 820, 57),
(3445, 'Trying to Onboard them ', '2025-06-04 14:36:40.498', 10605, 821, 32),
(3447, 'we are placing our order tomorrow ', '2025-06-04 14:46:41.342', 10605, 822, 20),
(3448, 'following up on payment ', '2025-06-04 14:47:54.351', 10605, 823, 20),
(3453, 'pending orders ', '2025-06-04 14:53:59.611', 10605, 824, 26),
(3456, 'They\'re well stocked for now', '2025-06-04 15:09:30.795', 10605, 825, 28),
(3457, 'waiting for danta to make a call to the client to place order ', '2025-06-04 15:12:05.474', 10605, 826, 20),
(3460, 'dantra debt has made them not ', '2025-06-05 06:21:07.958', 10605, 827, 26),
(3465, 'well stocked ', '2025-06-05 07:07:59.187', 10605, 828, 7),
(3469, 'They\'re well stocked. doing well in pouches but the Vapes are slow moving ', '2025-06-05 07:14:53.808', 10605, 829, 21),
(3472, 'well stocked\nwell displayed\nrrp 2000 for 9k puffs\nrrp 1570 for 3k puffs.\ncompetition:Gogo\nmost moving:blue razz', '2025-06-05 07:25:07.703', 10605, 830, 64),
(3477, 'Following up on listing ', '2025-06-05 07:40:26.749', 10605, 831, 35),
(3485, 'waiting on pending order from the office', '2025-06-05 07:49:18.397', 10605, 832, 35),
(3489, 'have an order ', '2025-06-05 07:51:35.288', 10605, 833, 62),
(3491, 'well displayed.\ncompetition:none\n\nplacing an order on vapes on saturday.', '2025-06-05 07:52:20.716', 10605, 834, 64),
(3495, 'well stocked with vapes\nrrp 2000 for 9k\nrrp 1570 for 3k\ncompetition:none', '2025-06-05 08:00:32.797', 10605, 835, 64),
(3497, 'Low customer turn out , they are not willing to stock at the moment ', '2025-06-05 08:04:06.119', 10605, 836, 35),
(3498, 'following up on boarding with the outlet ', '2025-06-05 08:11:21.417', 10605, 837, 35),
(3504, 'waiting for delivery of GP first', '2025-06-05 08:15:36.987', 10605, 838, 26),
(3506, 'Exchange received successfully ', '2025-06-05 08:16:28.496', 10605, 839, 73),
(3507, 'They are yet to receive their order.Competitor is Gogo.', '2025-06-05 08:16:59.728', 10605, 840, 51),
(3513, 'low on vapes stock...person in chqrge says theyve already requested HQ for restock.\nwell displayed\ncompetition:none\n', '2025-06-05 08:23:58.728', 10605, 841, 64),
(3516, 'The outlet has placed an order ', '2025-06-05 08:25:21.508', 10605, 842, 23),
(3517, 'well stocked for now \n*competitetor hart', '2025-06-05 08:25:36.302', 10605, 843, 7),
(3521, 'well stocked for now ', '2025-06-05 08:34:28.021', 10605, 844, 7),
(3524, 'Following up with Stella Kisii wine\'s Urgency on stocking. ', '2025-06-05 08:36:46.595', 10605, 845, 35),
(3534, 'waiting for an order for the 9000 puffs', '2025-06-05 08:51:33.565', 10605, 846, 39),
(3538, 'The outlet has placed an order for the Goldpouches ', '2025-06-05 08:54:44.753', 10605, 847, 23),
(3539, 'recently received pouches \nmovement of stock is good ', '2025-06-05 08:54:47.127', 10605, 848, 31),
(3542, 'They did an order today ', '2025-06-05 08:58:35.152', 10605, 849, 22),
(3548, 'stock moving on the ', '2025-06-05 09:04:30.525', 10605, 850, 17),
(3549, 'stock moving on well,no competitor ', '2025-06-05 09:05:37.387', 10605, 851, 17),
(3554, 'Owner is not in to process payment. ', '2025-06-05 09:11:24.519', 10605, 852, 57),
(3555, 'The outlet has placed an order for the 5 dot Goldpouches.', '2025-06-05 09:11:34.325', 10605, 853, 23),
(3556, 'pouches not received', '2025-06-05 09:13:15.796', 10605, 854, 50),
(3561, 'They are well stocked ', '2025-06-05 09:15:47.621', 10605, 855, 22),
(3566, 'Will make another order next week.', '2025-06-05 09:19:30.416', 10605, 856, 73),
(3567, 'still promising to stock,I will keep on following up ', '2025-06-05 09:19:36.537', 10605, 857, 7),
(3568, 'waiting feedback from owner ', '2025-06-05 09:21:33.174', 10605, 858, 40),
(3569, 'absence of supervisor whom I had to confirm an order we placed since it is new recrute outlet ', '2025-06-05 09:21:42.766', 10605, 859, 62),
(3573, 'moving well', '2025-06-05 09:22:56.116', 10605, 860, 46),
(3579, 'well stocked', '2025-06-05 09:31:21.534', 10605, 861, 63),
(3581, 'This outlet has closed. Building is currently under demolition. ', '2025-06-05 09:32:56.124', 10605, 862, 57),
(3583, 'They\'re well stocked and doing well, only 2 flavors for 9000puffs strawberry Ice cream and blue Razz has sold out and we\'ve placed the order ', '2025-06-05 09:33:07.743', 10605, 863, 21),
(3584, 'They\'re well stocked and doing well, only 2 flavors for 9000puffs strawberry Ice cream and blue Razz has sold out and we\'ve placed the order ', '2025-06-05 09:33:20.862', 10605, 864, 21),
(3586, 'vape is being sold at 2 k', '2025-06-05 09:34:36.343', 10605, 865, 48),
(3593, 'one competitor on pouches,stock moving on well compared to our competitor,to place an order of pouches  this week ', '2025-06-05 09:42:35.557', 10605, 866, 17),
(3597, 'have haert stock 18 pcs selling at 1900\nit\'s moving more because of the price', '2025-06-05 09:46:07.194', 10605, 867, 48),
(3601, 'not yet received their order', '2025-06-05 09:48:03.479', 10605, 868, 63),
(3603, 'waiting to get an order on the vapes', '2025-06-05 09:50:16.494', 10605, 869, 32),
(3604, 'They received  stocks  for vapes and also pouches.', '2025-06-05 09:50:24.802', 10605, 870, 51),
(3605, 'Need for a display. We placed an order but has not been delivered.', '2025-06-05 09:50:29.344', 10605, 871, 73),
(3612, 'They did an order', '2025-06-05 09:54:43.043', 10605, 872, 22),
(3615, 'They did an order on lastweek', '2025-06-05 09:55:23.824', 10605, 873, 22),
(3620, 'received the order', '2025-06-05 09:58:29.110', 10605, 874, 48),
(3621, 'placed order this week ', '2025-06-05 09:58:36.264', 10605, 875, 62),
(3623, 'The Supervisor requested I come for the order tomorrow. She is doing stock takes and she is alon', '2025-06-05 09:59:49.922', 10605, 876, 23),
(3624, 'Vape codes are not active ', '2025-06-05 10:00:12.263', 10605, 877, 30),
(3625, 'Talked with the owner will consider giving me an order once the business picks because it\'s a new outlet ', '2025-06-05 10:00:39.121', 10605, 878, 32),
(3627, 'The woosh vapes have began to move  because they are rechargeable. \nThe competitor is hart .', '2025-06-05 10:02:34.763', 10605, 879, 51),
(3628, 'They can\'t place the order for the vapes but they have placed an order for the pouches 10 pieces 5 dot.mixed flavours', '2025-06-05 10:04:23.293', 10605, 880, 6),
(3634, 'expecting a reorder once the four pieces are over', '2025-06-05 10:16:07.522', 10605, 881, 39),
(3638, 'zinasonga but slow juu azija display iwa', '2025-06-05 10:18:11.109', 10605, 882, 48),
(3641, 'No sales during low season. ', '2025-06-05 10:19:21.919', 10605, 883, 57),
(3646, 'They only received 10pcs of pouches \nThey also placed an order yet to receive ', '2025-06-05 10:21:26.625', 10605, 884, 31),
(3647, 'They are well stócked', '2025-06-05 10:21:48.615', 10605, 885, 22),
(3650, 'product moving on well,to place an order of 3000puffs due to clients demand,\nonly one competitor in the shop', '2025-06-05 10:22:34.827', 10605, 886, 17),
(3654, 'product pucking up the pace', '2025-06-05 10:26:03.228', 10605, 887, 46),
(3661, 'well stocked ', '2025-06-05 10:28:43.684', 10605, 888, 63),
(3664, 'They received their order... ', '2025-06-05 10:30:24.322', 10605, 889, 30),
(3668, 'They received their order of pouches.\nHart is the competitor. ', '2025-06-05 10:34:21.343', 10605, 890, 51),
(3671, 'stock moving slowly because of competitor,,,innobar and robust', '2025-06-05 10:36:27.287', 10605, 891, 50),
(3674, 'we\'ve placed order for Vapes ', '2025-06-05 10:37:05.423', 10605, 892, 21),
(3675, 'we\'ve placed order for Vapes ', '2025-06-05 10:37:29.412', 10605, 893, 21),
(3680, 'They are well stocked', '2025-06-05 10:38:32.461', 10605, 894, 22),
(3683, 'will re order by next week', '2025-06-05 10:39:53.151', 10605, 895, 46),
(3686, 'They received their order ', '2025-06-05 10:41:45.009', 10605, 896, 30),
(3687, 'order placed. not yet delivered. ', '2025-06-05 10:41:57.322', 10605, 897, 47),
(3693, 'to place orders after settling last invoice payment,no competitor on both products', '2025-06-05 10:48:04.777', 10605, 898, 17),
(3694, 'they have zero stock levels still trying to push for a restock ', '2025-06-05 10:48:23.046', 10605, 899, 39),
(3697, 'moving slowly ', '2025-06-05 10:49:35.651', 10605, 900, 63),
(3699, 'we will be placing orders today for pouches ', '2025-06-05 10:58:53.828', 10605, 901, 31),
(3704, 'expecting a reorder soon', '2025-06-05 11:04:55.342', 10605, 902, 39),
(3705, 'not yet received their order for 9k puffs ', '2025-06-05 11:05:32.862', 10605, 903, 63),
(3710, 'They have requested the product to be returned to the office and a cheque issued for the amount worth the products ', '2025-06-05 11:11:06.580', 10605, 904, 23),
(3716, 'will place order this weekend ', '2025-06-05 11:22:21.322', 10605, 905, 62),
(3721, 'Trying Soo hard to Onboard them ', '2025-06-05 11:30:35.144', 10605, 906, 32),
(3722, 'gogo 10000 rrp 2500\ngogo 16000 rrp 3300\nGogo is the competitor. \n', '2025-06-05 11:30:49.565', 10605, 907, 51),
(3723, 'Revisit by 15th for cheque collection.', '2025-06-05 11:31:38.603', 10605, 908, 57),
(3726, 'we placed an order today. 10pcs 5dots', '2025-06-05 11:35:20.084', 10605, 909, 47),
(3728, 'stocks not very well displayed , little space', '2025-06-05 11:45:30.552', 10605, 910, 26),
(3734, 'not able to order due slow moving products ', '2025-06-05 11:49:18.226', 10605, 911, 62),
(3739, 'stocked', '2025-06-05 11:57:12.546', 10605, 912, 50),
(3740, 'Order not received, their codes are not updated yet.', '2025-06-05 11:58:41.062', 10605, 913, 23),
(3743, 'well stocked , well displayed ', '2025-06-05 12:00:52.214', 10605, 914, 26),
(3745, 'they\'re well stocked but the stocks are moving slow ', '2025-06-05 12:02:18.412', 10605, 915, 21),
(3751, 'collected the cheque waiting for the delivery ', '2025-06-05 12:07:41.044', 10605, 916, 39),
(3754, 'will place order on Vapes next visit ', '2025-06-05 12:08:38.897', 10605, 917, 62),
(3757, 'The client is completely stocked out and has not received his order. I called Nicholas and said that they will receive the order today\n', '2025-06-05 12:13:43.450', 10605, 918, 23),
(3761, 'They\'re well stocked but the movement of the stocks is slow ', '2025-06-05 12:25:08.317', 10605, 919, 21),
(3762, 'in a meeting with the manager ', '2025-06-05 12:31:14.222', 10605, 920, 46),
(3763, 'Placed an order for pouches 20pcs', '2025-06-05 12:38:17.788', 10605, 921, 30),
(3770, 'will place order next visit ', '2025-06-05 12:42:45.987', 10605, 922, 62),
(3773, 'No sales made since last visit', '2025-06-05 12:45:49.597', 10605, 923, 57),
(3779, 'well stocked now', '2025-06-05 13:01:45.291', 10605, 924, 46),
(3780, 'no competitor products. to pay the pending invoice. ', '2025-06-05 13:02:03.688', 10605, 925, 47),
(3790, 'The shop was earlier closed and is still closed. was to place an order today. will make follow up over a call. ', '2025-06-05 14:19:55.956', 10605, 926, 35),
(3793, 'the movement is very slow', '2025-06-05 14:33:16.561', 10605, 927, 26),
(3795, 'will restock soon', '2025-06-05 14:37:28.312', 10605, 928, 32),
(3796, 'Trying to Onboard them ', '2025-06-05 14:40:42.059', 10605, 929, 32),
(3800, 'Sales moving fine', '2025-06-05 14:56:06.921', 10605, 930, 32),
(3802, 'well stocked slow movement ', '2025-06-05 15:05:25.963', 10605, 931, 26),
(3807, 'ordered 7 PCs for a start ', '2025-06-05 15:09:22.794', 10605, 932, 7),
(3809, 'They are yet to receive their Sunday order.', '2025-06-05 16:30:23.505', 10605, 933, 51),
(3813, 'to place an order of 9000puffs and pouches next week.', '2025-06-07 06:24:10.848', 10605, 934, 17),
(3816, 'They movement is very low', '2025-06-07 06:37:44.489', 10605, 935, 22),
(3819, 'Order to be processed tomorrow ', '2025-06-07 07:10:26.381', 10605, 936, 30),
(3829, 'They movement is okay in the outlet', '2025-06-07 07:33:34.371', 10605, 937, 22),
(3832, 'They have a pending order', '2025-06-07 07:42:39.780', 10605, 938, 30),
(3835, 'well displayed\ncompetition:booster\nvapes movement:slow\n3k puffs rrp 1570/=\nlow stock...ordering GP today.\n', '2025-06-07 08:10:48.942', 10605, 939, 64),
(3839, 'stock moving on well', '2025-06-07 08:16:05.438', 10605, 940, 17),
(3840, 'Very slow moving ', '2025-06-07 08:16:23.723', 10605, 941, 30),
(3848, 'they are out of stocks', '2025-06-07 08:26:41.412', 10605, 942, 22),
(3850, 'are placing order recently ', '2025-06-07 08:28:53.507', 10605, 943, 62),
(3861, 'placed their order last week,stock to be delivered in Monday.\n', '2025-06-07 08:45:11.068', 10605, 944, 17),
(3862, 'They have only sold two PCs so far.', '2025-06-07 08:46:05.101', 10605, 945, 23),
(3865, 'Had a lengthy meeting again with the store manager and of the Indian Manager\'s ', '2025-06-07 08:48:56.857', 10605, 946, 35),
(3869, 'we placed order for the vapes and we shall add another one on 12th', '2025-06-07 08:51:41.697', 10605, 947, 21),
(3872, 'Persuading on an order. ', '2025-06-07 09:00:16.685', 10605, 948, 35),
(3882, 'we are placing our order next week ', '2025-06-07 09:18:29.760', 10605, 949, 20),
(3885, 'Sakes have slowed down during low season. ', '2025-06-07 09:22:24.191', 10605, 950, 57),
(3886, 'pouches are selling well ', '2025-06-07 09:23:48.085', 10605, 951, 7),
(3888, 'They are requesting an exchange for the 9000 puffs with 3000 puffs since the product is not moving and the order was placed last year November.', '2025-06-07 09:30:02.861', 10605, 952, 23),
(3889, 'following up on a reorder after previous return of stocks due to late payments ', '2025-06-07 09:31:09.073', 10605, 953, 35),
(3895, 'absence of liquor manager but confirmed in a call would make order recently ', '2025-06-07 09:43:09.877', 10605, 954, 62),
(3899, 'pending delivery ', '2025-06-07 09:48:34.055', 10605, 955, 26),
(3900, 'products are well displayed and sales are good \ncompetitor hard ', '2025-06-07 09:49:18.459', 10605, 956, 19),
(3902, 'we are not getting deliveries what might be the issue ', '2025-06-07 10:00:35.084', 10605, 957, 20),
(3904, 'The owner has not paid the pending balance yet', '2025-06-07 10:04:33.964', 10605, 958, 23),
(3906, 'Received several complaints about delayed B-C payments.', '2025-06-07 10:10:11.480', 10605, 959, 57),
(3909, 'Shop is due for closure and relocation.. ', '2025-06-07 10:12:43.650', 10605, 960, 30),
(3911, 'low stock on vapes\nplacing order today', '2025-06-07 10:13:38.931', 10605, 961, 64),
(3913, 'pushing for a restock ', '2025-06-07 10:19:00.288', 10605, 962, 39),
(3919, 'not yet stocked ', '2025-06-07 10:40:14.682', 10605, 963, 63),
(3920, 'Sky is currently in the market at 480.\nThe 3000puffs have been moving faster than 9000puffs. ', '2025-06-07 10:41:11.504', 10605, 964, 51),
(3922, 'not yet stocked ', '2025-06-07 10:41:53.223', 10605, 965, 63),
(3925, 'order placed ', '2025-06-07 11:12:18.262', 10605, 966, 20),
(3930, 'The competitor is  hart\nnon rechargeable rrp 1000\nRechargeable  rrp 1800\nBooster  rrp  700\nThey placed an order on the 2nd of this month but are yet to receive. ', '2025-06-07 11:23:57.810', 10605, 967, 51),
(3933, 'well stocked ', '2025-06-07 11:27:06.533', 10605, 968, 63),
(3936, 'Will give me an order once she is ready ', '2025-06-07 11:43:19.177', 10605, 969, 32),
(3940, 'Hart is the competitor \nselling at 1799,999\nThe movement is slow due to lack of a display. ', '2025-06-07 11:53:49.218', 10605, 970, 51),
(3941, 'waiting for the manager ', '2025-06-07 13:21:58.473', 10605, 971, 46),
(3942, 'Trying to Onboard them ', '2025-06-07 14:17:17.781', 10605, 972, 32),
(3946, 'today I met the new manager he will order on/by Monday \n', '2025-06-07 14:41:52.881', 10605, 973, 47),
(3950, 'order received. ', '2025-06-07 15:37:02.878', 10605, 974, 47),
(3954, 'Made an order last week Saturday.', '2025-06-09 06:47:55.002', 10605, 975, 73),
(3957, 'Products delivered successfully.', '2025-06-09 08:38:51.470', 10605, 976, 73),
(3958, 'they made an order and has not been delivered. And they claim many has been rejected. ', '2025-06-09 09:00:27.301', 10605, 977, 73),
(3961, 'still stocked, will order by next week', '2025-06-09 09:51:19.631', 10605, 978, 46),
(3964, 'products are moving better', '2025-06-09 10:28:32.059', 10605, 979, 57),
(3967, 'slow movement ', '2025-06-09 10:34:44.606', 10605, 980, 46),
(3969, 'selling well only being affected by low season ', '2025-06-09 10:35:58.970', 10605, 981, 57),
(3972, 'well stocked ', '2025-06-09 10:47:38.835', 10605, 982, 46),
(3974, 'They are still well stocked ', '2025-06-09 10:49:25.356', 10605, 983, 19),
(3977, 'Sales picking up', '2025-06-09 11:03:09.122', 10605, 984, 35),
(3979, 'No Stocks currently. They will place their order from end of July onwards', '2025-06-09 11:21:10.070', 10605, 985, 57),
(3982, 'we are doing a reorder today. ', '2025-06-09 11:29:21.529', 10605, 986, 35),
(3986, 'they received their order ', '2025-06-09 11:39:25.852', 10605, 987, 19),
(3992, 'needs a re order', '2025-06-09 11:56:52.764', 10605, 988, 46),
(3995, 'placing an order with them tomorrow for 5 dots pouches ', '2025-06-09 12:12:31.526', 10605, 989, 35),
(3997, 'They have been instructed to remove the vapes from display by their HQ. ', '2025-06-09 12:15:21.391', 10605, 990, 57),
(3999, 'Products still moving very slowly.', '2025-06-09 12:20:44.937', 10605, 991, 57),
(4002, 'They received their order and the exchange too ', '2025-06-09 12:42:34.742', 10605, 992, 35),
(4004, 'they will restock for the pouches by next week..', '2025-06-09 12:43:53.066', 10605, 993, 6),
(4015, 'well stocked', '2025-06-09 13:44:20.928', 10605, 994, 32),
(4018, 'well stocked ', '2025-06-09 14:00:24.154', 10605, 995, 46),
(4020, 'They will restock from their main branch ', '2025-06-09 14:21:16.927', 10605, 996, 28),
(4021, 'well stocked ', '2025-06-09 14:24:38.328', 10605, 997, 32),
(4023, 'well stocked ', '2025-06-09 14:34:09.978', 10605, 998, 32),
(4027, 'trying to onboard them ', '2025-06-09 14:57:26.346', 10605, 999, 18),
(4029, 'stocks available ', '2025-06-09 15:02:45.896', 10605, 1000, 18),
(4040, 'B2c program is making products move faster ', '2025-06-10 07:05:03.504', 10605, 1001, 62),
(4046, 'order not received', '2025-06-10 07:46:16.888', 10605, 1002, 50),
(4050, 'They\'re well stocked and doing well ', '2025-06-10 07:52:26.789', 10605, 1003, 21),
(4052, 'Need for a display ', '2025-06-10 07:53:10.666', 10605, 1004, 73),
(4054, 'Delivering pouches ', '2025-06-10 07:55:28.681', 10605, 1005, 57),
(4056, 'placed an order to be uplifted from goodwill 8 pieces ', '2025-06-10 07:58:24.313', 10605, 1006, 12),
(4059, 'They are well stocked they promise to place another order', '2025-06-10 08:06:39.768', 10605, 1007, 22),
(4060, 'Order placed for 5 dots Pouches ', '2025-06-10 08:06:55.830', 10605, 1008, 30),
(4067, 'still very well stocked', '2025-06-10 08:15:39.840', 10605, 1009, 57),
(4068, 'The line manager for the liquor store is not in, we will place order for the 3000puffs when he\'s in for the shift ', '2025-06-10 08:16:21.596', 10605, 1010, 21),
(4074, 'onee faulty vape not replaced waiting for replacement...', '2025-06-10 08:21:45.344', 10605, 1011, 52),
(4078, 'well stocked with pouches and vapes', '2025-06-10 08:24:32.515', 10605, 1012, 50),
(4081, 'we are placing order today', '2025-06-10 08:25:18.240', 10605, 1013, 22),
(4086, 'cheque collection end of month', '2025-06-10 08:32:40.742', 10605, 1014, 57),
(4088, 'There are no competitors .\nThe pouches are moving quickly.', '2025-06-10 08:34:45.137', 10605, 1015, 51),
(4089, 'placed an order earlier today', '2025-06-10 08:36:56.302', 10605, 1016, 17),
(4092, 'will consider stocking', '2025-06-10 08:39:53.740', 10605, 1017, 46),
(4095, 'low on all SKU\nPlacing order', '2025-06-10 08:40:38.308', 10605, 1018, 64),
(4097, 'Shared the catalogue and will give me feedback about stocking vapes', '2025-06-10 08:41:55.594', 10605, 1019, 32),
(4099, 'stock moving slowly ', '2025-06-10 08:43:17.188', 10605, 1020, 73),
(4101, 'Their main challenge they are facing is that they are selling in a kiosk like structure since they closed for renovations.', '2025-06-10 08:45:25.219', 10605, 1021, 23),
(4110, 'poor sales, cheque collection end month. ', '2025-06-10 08:51:40.237', 10605, 1022, 57),
(4113, 'well stocked\nwell displayed\nmovement:slow', '2025-06-10 08:53:35.870', 10605, 1023, 64),
(4121, 'They made a reorder for the five dot and the three dot.\nCompetitor is booster 1000\nharts rechargeable rrp 2000', '2025-06-10 09:06:18.520', 10605, 1024, 51),
(4126, 'well stocked and they are moving well ', '2025-06-10 09:09:02.001', 10605, 1025, 7),
(4127, 'They received their order and will make payments next week', '2025-06-10 09:09:59.203', 10605, 1026, 23),
(4132, 'moving slowly ', '2025-06-10 09:11:49.795', 10605, 1027, 63),
(4138, 'placed their order this week', '2025-06-10 09:16:07.143', 10605, 1028, 57),
(4144, 'customers are just enquiring about our  product  and showing  interest \nhopefully they will be sales soon', '2025-06-10 09:20:12.136', 10605, 1029, 48),
(4146, 'well displayed\nwell stocked\nrequested for GP Order.told will be placed', '2025-06-10 09:21:40.755', 10605, 1030, 64),
(4148, 'the movement is okay ', '2025-06-10 09:21:59.244', 10605, 1031, 39),
(4156, 'They are well stocked', '2025-06-10 09:37:41.856', 10605, 1032, 22),
(4160, 'we haven\'t received another display it\'s needed at naivas ', '2025-06-10 09:41:05.712', 10605, 1033, 52),
(4162, 'we are placing another order', '2025-06-10 09:41:50.895', 10605, 1034, 22),
(4170, 'Requesting Dantra to make an exchange for them, 3 dot to 5 dot since the product is not selling ', '2025-06-10 09:57:54.017', 10605, 1035, 23),
(4177, 'waiting for the order', '2025-06-10 09:59:46.928', 10605, 1036, 48),
(4179, 'They received stocked,', '2025-06-10 10:01:28.377', 10605, 1037, 22),
(4180, 'Need for a display ', '2025-06-10 10:02:16.003', 10605, 1038, 73),
(4183, 'well stocked \nwe\'ve placed order for the sold out flavors ', '2025-06-10 10:06:51.569', 10605, 1039, 21),
(4190, 'well stocked ', '2025-06-10 10:12:36.940', 10605, 1040, 63),
(4195, 'to make an order soon', '2025-06-10 10:18:17.302', 10605, 1041, 49),
(4197, 'have an pending order ', '2025-06-10 10:27:03.266', 10605, 1042, 62),
(4201, 'pushing for payment ', '2025-06-10 10:29:11.779', 10605, 1043, 49),
(4208, 'Placed 1 outer order foe pouches', '2025-06-10 10:36:57.227', 10605, 1044, 30),
(4209, '3 Dot 430\n5 dot  500\n9000puff 1900\nthe price if faer but selling under the counter is the big challenge ', '2025-06-10 10:37:41.701', 10605, 1045, 48);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(4214, 'The competitor is sky rrp 690 and booster rrp 820', '2025-06-10 10:42:35.984', 10605, 1046, 51),
(4217, 'Recieved their stocks today \nwell stocked ', '2025-06-10 10:44:20.853', 10605, 1047, 21),
(4221, 'They will place an order next week for the vapes once they reduce', '2025-06-10 10:48:09.173', 10605, 1048, 23),
(4223, 'placed an order for 10 pieces of gold pouches ', '2025-06-10 10:52:48.313', 10605, 1049, 12),
(4227, 'moving slowly but picking up ', '2025-06-10 10:54:49.287', 10605, 1050, 63),
(4231, 'pushing for a reorder ', '2025-06-10 10:57:06.217', 10605, 1051, 49),
(4233, 'it\'s been  slaw', '2025-06-10 10:57:54.227', 10605, 1052, 48),
(4234, 'waiting for feedback on the order', '2025-06-10 11:01:11.160', 10605, 1053, 32),
(4237, 'to restock them with 3000 puffs and gold pouches ', '2025-06-10 11:04:23.733', 10605, 1054, 12),
(4247, 'kumetulia tu', '2025-06-10 11:12:59.732', 10605, 1055, 48),
(4251, 'stocked', '2025-06-10 11:14:38.389', 10605, 1056, 46),
(4254, 'The order they made on the 1st is yet to arrive.\nHart is the competitor. ', '2025-06-10 11:15:38.270', 10605, 1057, 51),
(4257, 'They still have stock ', '2025-06-10 11:23:49.554', 10605, 1058, 30),
(4261, 'products moving slow order for 3000/puffs to be placed on Thursday', '2025-06-10 11:24:51.450', 10605, 1059, 50),
(4264, 'they don\'t have any vapes or pouches ', '2025-06-10 11:25:14.426', 10605, 1060, 6),
(4265, 'moving slowly but picking up ', '2025-06-10 11:25:24.663', 10605, 1061, 63),
(4266, 'pushing for payment \nhe promised  to pay on Friday ', '2025-06-10 11:25:43.634', 10605, 1062, 48),
(4270, 'They have placed an order for the 5 fots', '2025-06-10 11:35:21.780', 10605, 1063, 23),
(4271, 'They have placed an order for the 5 dots', '2025-06-10 11:35:43.756', 10605, 1064, 23),
(4285, 'stock out.\nawaiting delivery ', '2025-06-10 11:56:58.351', 10605, 1065, 46),
(4287, 'placed order last week but still not received ', '2025-06-10 12:00:32.412', 10605, 1066, 62),
(4293, 'making an order', '2025-06-10 12:15:58.842', 10605, 1067, 49),
(4299, 'very slow movement ', '2025-06-10 12:24:58.733', 10605, 1068, 49),
(4302, 'to place an order soon', '2025-06-10 12:37:57.491', 10605, 1069, 49),
(4305, 'They are going to place an order on Friday this week\n', '2025-06-10 12:40:25.189', 10605, 1070, 23),
(4308, 'Follow-up for order and payment ', '2025-06-10 12:44:28.095', 10605, 1071, 40),
(4314, 'well stocked ', '2025-06-10 12:55:40.958', 10605, 1072, 32),
(4316, 'placed an order from baseline ', '2025-06-10 12:57:03.313', 10605, 1073, 7),
(4319, 'huge debt for dantra', '2025-06-10 13:04:22.562', 10605, 1074, 26),
(4323, 'sudden use of maasai tobacco.\n', '2025-06-10 13:11:29.638', 10605, 1075, 44),
(4334, 'are more asking for display since have no other place to display ', '2025-06-10 13:47:09.764', 10605, 1076, 62),
(4337, 'pushing for payment ', '2025-06-10 13:49:07.885', 10605, 1077, 49),
(4340, 'Will place an order on Friday ', '2025-06-10 13:55:05.616', 10605, 1078, 32),
(4346, 'stocked in all SKUs ', '2025-06-10 14:10:56.614', 10605, 1079, 26),
(4350, 'To reorder next week', '2025-06-10 14:20:03.845', 10605, 1080, 20),
(4351, 'Are really interested with our vapes will be contacted soon', '2025-06-10 14:23:38.332', 10605, 1081, 32),
(4356, 'pouches are the fast moving ', '2025-06-10 14:37:43.108', 10605, 1082, 62),
(4360, 'Awaiting delivery for 5dot and vapes', '2025-06-10 14:48:50.034', 10605, 1083, 30),
(4361, 'Mounting also needed for them ', '2025-06-10 14:50:13.873', 10605, 1084, 30),
(4362, 'Delivery done last week ', '2025-06-10 15:06:10.829', 10605, 1085, 20),
(4369, 'The competitor is gogo.', '2025-06-10 15:44:34.057', 10605, 1086, 51),
(4371, 'we’ve ordered pouches twice this month vapes we are still stocked ', '2025-06-10 20:35:03.255', 10605, 1087, 20),
(4374, 'well displayed.\nplacing order', '2025-06-11 06:15:19.081', 10605, 1088, 64),
(4377, 'will place order mid month ', '2025-06-11 07:02:41.861', 10605, 1089, 62),
(4380, 'well displayed.\n\nwell stocked.\ncompetitor:Gogo', '2025-06-11 07:12:28.009', 10605, 1090, 64),
(4385, 'to place an order for 3000 puffs', '2025-06-11 07:34:39.239', 10605, 1091, 7),
(4388, 'had placed order last week of may but they still not received that is 5 dots', '2025-06-11 07:52:02.291', 10605, 1092, 62),
(4389, 'Made their first order today ', '2025-06-11 07:54:21.913', 10605, 1093, 73),
(4391, 'the manager is not pick my call, I well still keep follow-up ', '2025-06-11 07:55:13.640', 10605, 1094, 40),
(4395, 'trying to onboard them ', '2025-06-11 07:57:49.953', 10605, 1095, 7),
(4396, 'the are interested with our product ', '2025-06-11 07:58:11.255', 10605, 1096, 7),
(4398, 'Vapes movements is slow, they still have 3dots Pouches ', '2025-06-11 07:59:45.959', 10605, 1097, 30),
(4400, 'waiting for payment to be made for them to make a reorder.\nThe competitor is elfbar rrp 2500\nsolobar rrp 2600.    boost pro rrp 2500 elfbar rrp 2400.\nThe competitive advantage is that elfbar ', '2025-06-11 08:09:26.197', 10605, 1098, 51),
(4401, 'we have 6pcs and not ready to exchange with pouches ', '2025-06-11 08:10:45.612', 10605, 1099, 20),
(4404, 'pending from the office', '2025-06-11 08:16:08.274', 10605, 1100, 35),
(4408, 'Follow-up the stock but it\'s not yet arrived ', '2025-06-11 08:30:04.923', 10605, 1101, 40),
(4411, 'The movement is very low', '2025-06-11 08:34:56.304', 10605, 1102, 22),
(4412, 'since may they\'ve been placing orders and not delivered ', '2025-06-11 08:36:11.331', 10605, 1103, 21),
(4417, 'have not received their order yet.', '2025-06-11 08:42:43.809', 10605, 1104, 23),
(4421, 'waiting for stock to be delivered from they branch ', '2025-06-11 08:46:31.800', 10605, 1105, 40),
(4424, 'Placing an order today. ', '2025-06-11 08:48:43.621', 10605, 1106, 35),
(4430, 'The products are well displayed with all products visible.hart is the competitor  rrp 1800,1000.', '2025-06-11 08:52:29.228', 10605, 1107, 51),
(4434, 'well stocked ', '2025-06-11 08:53:43.054', 10605, 1108, 63),
(4435, 'slow movement ', '2025-06-11 08:53:54.621', 10605, 1109, 49),
(4439, 'collecting payment', '2025-06-11 08:54:36.376', 10605, 1110, 57),
(4440, 'Following up on order. ', '2025-06-11 08:55:04.211', 10605, 1111, 35),
(4444, 'They movement is very first', '2025-06-11 08:59:20.755', 10605, 1112, 22),
(4449, 'fair movement ', '2025-06-11 09:04:00.229', 10605, 1113, 49),
(4451, 'They want the vapes on consignment ', '2025-06-11 09:04:25.005', 10605, 1114, 32),
(4452, 'they haven\'t received their order yet from the office', '2025-06-11 09:04:44.520', 10605, 1115, 35),
(4455, 'Not selling from 30th May to date they are under instructions from their HQ after government ban. Requesting licences to put back products on shelves.', '2025-06-11 09:09:45.829', 10605, 1116, 57),
(4456, 'Order to be placed upon payment.. ', '2025-06-11 09:10:02.244', 10605, 1117, 30),
(4464, 'Product moving slowly, will order towards the end of the month.', '2025-06-11 09:14:25.442', 10605, 1118, 57),
(4469, 'have placed an order', '2025-06-11 09:16:15.229', 10605, 1119, 91),
(4471, 'they received their order ', '2025-06-11 09:17:21.519', 10605, 1120, 63),
(4477, 'movement is a bit slow \n pushing for payment ', '2025-06-11 09:22:48.445', 10605, 1121, 49),
(4480, 'order placed', '2025-06-11 09:26:36.278', 10605, 1122, 91),
(4486, 'Product is moving slowly with low season. They still have 19 pcs. Sold 11pcs within a 40 day period. ', '2025-06-11 09:32:16.152', 10605, 1123, 57),
(4490, 'pushing for payment ', '2025-06-11 09:34:05.174', 10605, 1124, 48),
(4491, 'There are no competitors. sky  is in the market rrp 480.', '2025-06-11 09:34:45.710', 10605, 1125, 51),
(4493, 'They are no stocks,they are waiting for account creation', '2025-06-11 09:37:01.859', 10605, 1126, 22),
(4494, 'The outlet has completely put the product under the desk and not selling due to the issue of licence withdrawal. I have informed them about the court order but are still reluctant\n', '2025-06-11 09:37:25.132', 10605, 1127, 23),
(4499, 'vapes are slowly moving more than the pouches ', '2025-06-11 09:44:54.271', 10605, 1128, 48),
(4505, 'well disolayed\nwill request for order top up.', '2025-06-11 09:47:46.243', 10605, 1129, 64),
(4507, 'not yet received their order ', '2025-06-11 09:49:21.972', 10605, 1130, 63),
(4510, 'Well stocked \nwe\'ve placed order for Vapes and Pouches ', '2025-06-11 09:55:16.358', 10605, 1131, 21),
(4515, 'I\'m sorting an issue they want exchange to all cooling mint ', '2025-06-11 09:57:23.762', 10605, 1132, 39),
(4517, 'well displayed\nrrp @1570 and 2000\n\nawaiting order delivery.', '2025-06-11 09:58:31.775', 10605, 1133, 64),
(4520, 'They are yet to receive their order and are complete out of stock for the pouches.', '2025-06-11 09:59:58.641', 10605, 1134, 51),
(4521, 'Order received successfully ', '2025-06-11 10:00:06.828', 10605, 1135, 73),
(4523, 'Made follow up call the shop was closed, I\'m expecting an order. ', '2025-06-11 10:00:47.154', 10605, 1136, 35),
(4526, 'pushing for payment \nsky pouches  21 pcs are available \nour product is moving  more even if the price is higher than of sky', '2025-06-11 10:03:57.659', 10605, 1137, 48),
(4530, 'They are well stocked', '2025-06-11 10:10:11.195', 10605, 1138, 22),
(4536, 'The outlet is well stocked, they will make their payment next week\n', '2025-06-11 10:13:22.399', 10605, 1139, 23),
(4539, 'stock moving slowly due to competitor', '2025-06-11 10:14:16.644', 10605, 1140, 50),
(4541, 'well stocked ', '2025-06-11 10:15:37.626', 10605, 1141, 63),
(4543, 'pushing for order of ek puff', '2025-06-11 10:15:58.572', 10605, 1142, 48),
(4544, 'Having a meeting with Rajesh the CEO of Shivling supermarket. ', '2025-06-11 10:17:11.512', 10605, 1143, 35),
(4551, 'no Competitors ', '2025-06-11 10:34:15.869', 10605, 1144, 48),
(4555, 'will place another order on Vapes mid month ', '2025-06-11 10:35:37.294', 10605, 1145, 62),
(4559, 'well stocked \nwe\'ve also placed order for the sold out flavors ', '2025-06-11 10:38:51.351', 10605, 1146, 21),
(4560, 'The pouches are moving quickly .The competitor is sky.', '2025-06-11 10:43:48.235', 10605, 1147, 51),
(4563, 'Our customers are complaining that the products are dry so the client is requesting for an exchange ', '2025-06-11 10:45:16.812', 10605, 1148, 73),
(4566, 'The movement is very low', '2025-06-11 10:47:48.193', 10605, 1149, 22),
(4568, 'well stocked follow-up for payment ', '2025-06-11 10:48:12.414', 10605, 1150, 40),
(4574, 'the movement is okay ', '2025-06-11 10:51:51.058', 10605, 1151, 39),
(4575, 'they have made a order for two pcs', '2025-06-11 10:53:06.201', 10605, 1152, 31),
(4578, 'We called the owner of the shop in regard to payment.he said he will clear the balance.', '2025-06-11 10:56:33.951', 10605, 1153, 23),
(4579, 'stock received today', '2025-06-11 10:56:34.373', 10605, 1154, 50),
(4587, 'they don\'t want to stock for us again due to our packaging ', '2025-06-11 11:11:59.953', 10605, 1155, 39),
(4588, 'Ipc faulty, suggested order to be placed tomorrow ', '2025-06-11 11:12:10.525', 10605, 1156, 30),
(4590, 'trying to onboard them, potential client since they are stocking other vapes', '2025-06-11 11:18:28.121', 10605, 1157, 39),
(4596, 'They have placed an order for the 5 dot, Goldpouches ', '2025-06-11 11:30:11.828', 10605, 1158, 23),
(4609, 'slow moving of the stocks', '2025-06-11 11:51:13.948', 10605, 1159, 50),
(4611, 'have received x booster only still not received ours', '2025-06-11 11:54:16.868', 10605, 1160, 62),
(4614, 'stocked no competitor stock expected to move', '2025-06-11 12:03:00.261', 10605, 1161, 50),
(4619, 'planned to stock vapes but they want a sample', '2025-06-11 12:09:12.108', 10605, 1162, 26),
(4622, 'waiting for pending payment ', '2025-06-11 12:34:07.467', 10605, 1163, 20),
(4632, 'since is first time are selling 650 each ', '2025-06-11 13:12:03.805', 10605, 1164, 62),
(4635, 'fair movement ', '2025-06-11 13:26:48.567', 10605, 1165, 49),
(4637, 'let the delivery be done without fail', '2025-06-11 13:28:18.598', 10605, 1166, 26),
(4643, 'only sold 1pc since last order date on 29th April. Poor sales affecting payments. ', '2025-06-11 13:42:52.920', 10605, 1167, 57),
(4645, 'closed down due to slow business ', '2025-06-11 13:44:54.039', 10605, 1168, 49),
(4651, 'fully stocked from their previous order. Extremely slow movement ', '2025-06-11 13:49:22.892', 10605, 1169, 49),
(4652, 'to place an order of pouches tomorrow ', '2025-06-11 13:49:59.846', 10605, 1170, 17),
(4655, 'will order vapes soon she will contact me ', '2025-06-11 14:05:34.653', 10605, 1171, 32),
(4658, 'fair movement. \nuplifting 20 pieces from their go down ', '2025-06-11 14:09:58.284', 10605, 1172, 49),
(4662, 'Following up on payment ', '2025-06-11 14:16:56.672', 10605, 1173, 32),
(4664, 'are asking whether they can share vapes stock since have vapes amounting 90 and less customer \nthen the fault which I confirmed Last month still not collected ', '2025-06-11 14:23:21.664', 10605, 1174, 62),
(4665, 'Follow-up for payment ', '2025-06-11 14:23:31.957', 10605, 1175, 40),
(4671, 'well stocked', '2025-06-11 14:27:45.138', 10605, 1176, 32),
(4674, 'Follow-up for payment, stock Controller was not around today ', '2025-06-11 14:41:58.454', 10605, 1177, 40),
(4675, 'pushing for an order ', '2025-06-11 14:41:58.657', 10605, 1178, 32),
(4676, 'trying to Onboard them ', '2025-06-11 14:47:46.391', 10605, 1179, 32),
(4677, 'They have received pouches and vapes which they currently ordered.\nsky is the competitor. ', '2025-06-11 15:21:57.142', 10605, 1180, 51),
(4679, 'Follow-up to see weather stock arrived ', '2025-06-12 06:17:43.455', 10605, 1181, 40),
(4684, 'well stocked for now they are not going to place an order ', '2025-06-12 06:38:50.703', 10605, 1182, 40),
(4687, 'well stocked ', '2025-06-12 06:50:04.280', 10605, 1183, 32),
(4689, 'well stocked on GP\nlow stock vapes...placing order.', '2025-06-12 06:51:10.164', 10605, 1184, 64),
(4692, 'well stocked\nwell displayed...prices comparatively high.', '2025-06-12 07:00:11.481', 10605, 1185, 64),
(4696, 'no 5dots at dantra', '2025-06-12 07:22:30.166', 10605, 1186, 26),
(4699, 'well stocked and displayed.\nOrder was received.', '2025-06-12 07:32:36.443', 10605, 1187, 64),
(4702, 'Need for a display ', '2025-06-12 07:44:55.369', 10605, 1188, 73),
(4708, 'They placed an order which is yet to arrive.\nThe competitor is gogo.\n10000 puffs rrp 2500.\n\n16000 puffs rrp 3300.', '2025-06-12 07:50:42.285', 10605, 1189, 51),
(4711, 'in need to of alight box', '2025-06-12 07:55:51.690', 10605, 1190, 35),
(4717, 'low stock...had placed order but wasnt delivered due to pending payment.\n\nWill collect payment today.', '2025-06-12 07:58:21.798', 10605, 1191, 64),
(4718, 'low stock\nwell displayed.', '2025-06-12 07:58:41.698', 10605, 1192, 64),
(4720, 'will place order this mid month ', '2025-06-12 08:00:39.512', 10605, 1193, 62),
(4725, 'They have received their order today ', '2025-06-12 08:07:41.994', 10605, 1194, 23),
(4728, 'they called in concerning their order. not yet received. ', '2025-06-12 08:13:40.993', 10605, 1195, 35),
(4731, 'new client trying to onboard them ', '2025-06-12 08:19:51.802', 10605, 1196, 7),
(4738, 'make an order tomorrow ', '2025-06-12 08:40:17.234', 10605, 1197, 48),
(4743, 'stock moving slow hence no competitor ', '2025-06-12 08:46:19.823', 10605, 1198, 50),
(4746, 'The pouches are moving quickly .They have few of the vapes.\ncompetitor is hart vapes.', '2025-06-12 08:50:20.585', 10605, 1199, 51),
(4749, 'They\'re well stocked. \nwe\'ve placed order for the Gold pouches ', '2025-06-12 08:51:48.235', 10605, 1200, 21),
(4750, 'outlet stocked on 9000 puffs they are in need of pouches', '2025-06-12 08:52:32.485', 10605, 1201, 50),
(4755, 'Will make an order on Sunday ', '2025-06-12 09:00:35.555', 10605, 1202, 73),
(4756, 'Trying to Onboard them ', '2025-06-12 09:01:13.786', 10605, 1203, 32),
(4763, 'well stocked ', '2025-06-12 09:12:15.309', 10605, 1204, 63),
(4770, 'well stocked ', '2025-06-12 09:16:44.895', 10605, 1205, 21),
(4773, 'they Are well stocked', '2025-06-12 09:17:41.042', 10605, 1206, 22),
(4774, 'The codes are blocked for the vapes.\nThe placed an order for the five dot.', '2025-06-12 09:18:34.274', 10605, 1207, 51),
(4775, 'The product is slow selling in this outlet', '2025-06-12 09:19:12.584', 10605, 1208, 23),
(4777, 'No order at the moment ', '2025-06-12 09:33:46.901', 10605, 1209, 30),
(4778, 'have received another stock today ', '2025-06-12 09:35:46.837', 10605, 1210, 62),
(4782, 'not yet stocked ', '2025-06-12 09:42:35.635', 10605, 1211, 63),
(4784, 'making an order ', '2025-06-12 09:43:49.194', 10605, 1212, 49),
(4787, 'pouches are selling than vapes', '2025-06-12 09:54:45.529', 10605, 1213, 20),
(4788, 'out of stock to place an order this week ', '2025-06-12 09:54:59.523', 10605, 1214, 17),
(4791, 'Extremely slow movement. \nPushing for payment ', '2025-06-12 09:57:43.455', 10605, 1215, 49),
(4796, 'order not received,,,,pouches 10 pieces', '2025-06-12 10:02:44.598', 10605, 1216, 50),
(4803, 'Received product recently ', '2025-06-12 10:11:29.643', 10605, 1217, 31),
(4805, 'Awaiting delivery of their order. ', '2025-06-12 10:12:39.771', 10605, 1218, 57),
(4806, 'Nasim has not yet given an order to Titus Finance.', '2025-06-12 10:13:21.845', 10605, 1219, 23),
(4810, 'they received their order ', '2025-06-12 10:14:35.098', 10605, 1220, 63),
(4813, 'Very well stocked. Owner is not in to process payment. ', '2025-06-12 10:26:29.837', 10605, 1221, 57),
(4817, 'Well stocked. ', '2025-06-12 10:30:19.867', 10605, 1222, 21),
(4819, 'waiting for their feedback on vapes', '2025-06-12 10:34:23.223', 10605, 1223, 32),
(4823, 'extremely slow movement ', '2025-06-12 10:39:56.761', 10605, 1224, 49),
(4833, 'There are no competitors. \nThe product have moving slowly.', '2025-06-12 10:49:41.057', 10605, 1225, 51),
(4834, 'well stocked ', '2025-06-12 10:50:23.055', 10605, 1226, 21),
(4838, 'They are placing another order', '2025-06-12 10:59:53.936', 10605, 1227, 22),
(4839, 'The vapes are moving slowly. The competitor is hart.\n', '2025-06-12 11:03:38.903', 10605, 1228, 51),
(4843, 'zinasonga \nbut price ni 2k for 3k puff', '2025-06-12 11:06:42.832', 10605, 1229, 48),
(4846, 'always placing orders but they will not receive even this week we have placed still not arrived ', '2025-06-12 11:07:23.031', 10605, 1230, 62),
(4847, 'well stocked ', '2025-06-12 11:08:43.454', 10605, 1231, 46),
(4850, 'They received their order ', '2025-06-12 11:15:44.632', 10605, 1232, 63),
(4853, 'They are reluctant in stocking vapes and Pouches ', '2025-06-12 11:24:20.754', 10605, 1233, 32),
(4857, 'slow sales.. ', '2025-06-12 11:25:41.835', 10605, 1234, 35),
(4859, 'Waiting for feedback from their HQ on when to return Woosh Vapes and pouches back to the shelves after government ban.', '2025-06-12 11:28:32.943', 10605, 1235, 57),
(4860, 'pushing for the three', '2025-06-12 11:28:36.545', 10605, 1236, 48),
(4861, 'following up on boarding. meeting the manager over our products. ', '2025-06-12 11:31:02.532', 10605, 1237, 35),
(4865, 'Still under SoR. ', '2025-06-12 11:33:40.587', 10605, 1238, 23),
(4869, 'pushing for payment ', '2025-06-12 11:34:32.432', 10605, 1239, 48),
(4870, 'They are well stocked', '2025-06-12 11:35:06.808', 10605, 1240, 22),
(4872, 'They think that Vapes are burnt but I have forwarded to them the certificates', '2025-06-12 11:38:27.995', 10605, 1241, 32),
(4874, 'working on an order today ', '2025-06-12 11:40:13.181', 10605, 1242, 35),
(4882, 'Still well stocked on 3000 puffs. To place their order from July onwards.', '2025-06-12 11:49:33.538', 10605, 1243, 57),
(4886, 'will make an order tomorrow ', '2025-06-12 11:50:03.312', 10605, 1244, 73),
(4888, 'waiting for their order since have less stock', '2025-06-12 11:51:32.429', 10605, 1245, 62),
(4889, 'Placed an order for vapes', '2025-06-12 11:54:03.737', 10605, 1246, 30),
(4893, 'it\'s a new outlet they promised to stock pouches from distributor in their next purchase ', '2025-06-12 11:56:47.268', 10605, 1247, 7),
(4894, 'pushing for reorder ', '2025-06-12 11:57:01.313', 10605, 1248, 48),
(4899, 'pushing for payment as we wait for next order ', '2025-06-12 12:00:29.173', 10605, 1249, 49),
(4900, 'it\'s a new outlet they promised to stock pouches from distributor in their next purchase ', '2025-06-12 12:02:34.638', 10605, 1250, 7),
(4901, 'placing an order tomorrow ', '2025-06-12 12:04:12.234', 10605, 1251, 35),
(4903, 'fair movement. Expecting an order soon', '2025-06-12 12:10:23.467', 10605, 1252, 49),
(4906, 'trying to onboarding them on pouches ', '2025-06-12 12:18:15.680', 10605, 1253, 7),
(4913, 'awaiting delivery ', '2025-06-12 12:35:33.439', 10605, 1254, 46),
(4917, 'the available five pcs have remained for two months without selling even with the help of B2C', '2025-06-12 12:38:11.560', 10605, 1255, 62),
(4918, 'Following up on feedback on stocking vapes. ', '2025-06-12 12:38:46.425', 10605, 1256, 57),
(4919, 'They will pay the pending invoice and make payments ', '2025-06-12 12:47:33.725', 10605, 1257, 23),
(4924, 'naivas had received stocks. ', '2025-06-12 13:01:42.118', 10605, 1258, 47),
(4926, 'naivas greenwood received 23pcs vapes', '2025-06-12 13:06:54.137', 10605, 1259, 47),
(4927, 'naivas greenwood received 23pcs vapes', '2025-06-12 13:07:14.805', 10605, 1260, 47),
(4928, '5 dots is moving faster which they received their order last week ', '2025-06-12 13:07:38.433', 10605, 1261, 62),
(4935, 'placed an order for 20pcs gold pouches . ', '2025-06-12 13:40:37.533', 10605, 1262, 47),
(4938, 'to pay the pending invoices ', '2025-06-12 14:01:33.596', 10605, 1263, 47),
(4943, 'slow moving ', '2025-06-12 14:28:20.538', 10605, 1264, 20),
(4945, 'paid all the pending invoices. ', '2025-06-12 14:29:32.072', 10605, 1265, 47),
(4948, 'will make an order by Sunday ', '2025-06-12 14:34:08.992', 10605, 1266, 46),
(4952, 'Stocked', '2025-06-12 14:39:38.873', 10605, 1267, 20),
(4956, 'pouches are moving. but slow', '2025-06-12 14:44:25.973', 10605, 1268, 47),
(4959, 'still stocked', '2025-06-12 14:47:53.230', 10605, 1269, 46),
(4960, 'vapes are slow  moving', '2025-06-12 14:47:56.765', 10605, 1270, 26),
(4962, 'stocks available ', '2025-06-12 15:03:12.076', 10605, 1271, 20),
(4966, 'the new manager has been taking me back and forth. I\'ll ask Susan to call him', '2025-06-12 15:20:38.551', 10605, 1272, 47),
(4970, 'there was an issue on display, sorting out with Susan ', '2025-06-12 15:25:49.924', 10605, 1273, 35),
(4971, 'for a start ', '2025-06-12 15:32:41.189', 10605, 1274, 7),
(4973, 'will get an order soon', '2025-06-12 16:15:26.639', 10605, 1275, 32),
(4981, 'trying to onboard them though they are telling me to visit their main hqs in Nairobi ', '2025-06-13 06:53:16.845', 10605, 1276, 7),
(4984, 'well displayed\nwell stocked\nslow movement...outlet is new\nrrp @1570 and @2000 for vapes\n\'GP will be reordered once vapes move\'-management.', '2025-06-13 07:12:49.315', 10605, 1277, 64),
(4990, 'placed a display today ', '2025-06-13 07:31:43.201', 10605, 1278, 35),
(4995, 'Following up on a reorder ', '2025-06-13 07:42:33.506', 10605, 1279, 35),
(4999, 'well stocked\nwell displayed\nprices: GP @500 and 3k puffs @1570', '2025-06-13 07:46:04.768', 10605, 1280, 64),
(5001, 'well stocked ', '2025-06-13 07:47:44.747', 10605, 1281, 21),
(5003, 'Placed an order for 30pcs vapes the rest are well stocked', '2025-06-13 07:55:23.433', 10605, 1282, 30),
(5006, 'They will make payments for the pending invoice next week', '2025-06-13 07:58:56.154', 10605, 1283, 23),
(5009, 'well stocked to place an order next week on pouches ', '2025-06-13 08:04:04.635', 10605, 1284, 17),
(5017, 'we have placed our first order ', '2025-06-13 08:19:50.370', 10605, 1285, 62),
(5018, 'to deal with the gold pouches.they move better than the pouches.', '2025-06-13 08:32:49.639', 10605, 1286, 44),
(5021, 'low stock...order not received yet.\n', '2025-06-13 08:34:50.750', 10605, 1287, 64),
(5023, 'the GP are in slow movement ', '2025-06-13 08:42:35.719', 10605, 1288, 26),
(5029, 'placed order ', '2025-06-13 08:51:48.930', 10605, 1289, 62),
(5030, 'doing well on 9000 puffs', '2025-06-13 08:52:39.928', 10605, 1290, 50),
(5034, 'Stock is moving slowly ', '2025-06-13 08:56:29.275', 10605, 1291, 73),
(5035, 'doing well on 9000 puffs', '2025-06-13 08:56:31.392', 10605, 1292, 50),
(5038, 'places an order today', '2025-06-13 08:59:45.012', 10605, 1293, 35),
(5040, 'They well stocked', '2025-06-13 09:00:31.676', 10605, 1294, 22),
(5049, 'Following up on boarding. ', '2025-06-13 09:24:36.133', 10605, 1295, 35),
(5057, 'The products are well displayed. The competitor is hart .', '2025-06-13 09:29:58.316', 10605, 1296, 51),
(5059, 'Made an inquiry if we could get more than 9000puffs. Made an order for vapes today ', '2025-06-13 09:30:39.121', 10605, 1297, 73),
(5062, 'They received their order for the Goldpouches.', '2025-06-13 09:31:15.915', 10605, 1298, 23),
(5063, 'Well stocked ', '2025-06-13 09:31:52.150', 10605, 1299, 21),
(5068, 'outlet is improving', '2025-06-13 09:38:01.814', 10605, 1300, 50),
(5069, 'There was an issue yesterday over display and so far I\'m asked to waiting on feedback where they will be mounted ', '2025-06-13 09:38:18.414', 10605, 1301, 35),
(5073, 'Movement improvement has been noted', '2025-06-13 09:47:19.465', 10605, 1302, 49),
(5079, 'well stocked ', '2025-06-13 09:57:25.767', 10605, 1303, 21),
(5080, 'Received their order ', '2025-06-13 09:57:39.853', 10605, 1304, 73),
(5083, 'placed order last weekend ', '2025-06-13 09:59:46.835', 10605, 1305, 62),
(5088, 'The competitor is gogo.', '2025-06-13 10:08:11.661', 10605, 1306, 51),
(5093, 'to place their order this week', '2025-06-13 10:14:19.308', 10605, 1307, 17),
(5094, 'They will place their order today.', '2025-06-13 10:16:48.427', 10605, 1308, 23),
(5096, 'outlet has a slow selling due to renovations ongoing', '2025-06-13 10:18:47.392', 10605, 1309, 50),
(5102, 'Clients prefer the 2500 puffs vapes. The current ones are not too good ', '2025-06-13 10:26:04.241', 10605, 1310, 49),
(5109, 'They have enough stock. \nThe vapes are moving slowly but the gold Pouches are fast moving ', '2025-06-13 10:37:33.864', 10605, 1311, 21),
(5110, 'There is no competitors in the market at the moment.\nBullion was previously available but right now there are no bullion vapes available. ', '2025-06-13 10:42:07.483', 10605, 1312, 51),
(5115, 'There are currently no products available. The  owner is currently not arround hence no check can be issued till july.', '2025-06-13 10:53:10.230', 10605, 1313, 51),
(5116, 'They are well stocked we are placing another order', '2025-06-13 10:56:10.799', 10605, 1314, 22),
(5118, 'Good movement ', '2025-06-13 10:58:05.533', 10605, 1315, 49),
(5121, 'well stocked ', '2025-06-13 11:06:37.387', 10605, 1316, 63),
(5126, 'movement is slow due to the area strategy', '2025-06-13 11:15:51.817', 10605, 1317, 50),
(5127, 'Still engaging management ', '2025-06-13 11:15:54.241', 10605, 1318, 49),
(5131, 'slow movement on both items', '2025-06-13 11:18:29.527', 10605, 1319, 26),
(5134, 'movement is slow', '2025-06-13 11:23:41.235', 10605, 1320, 32),
(5136, 'potential client trying to onboard them ', '2025-06-13 11:23:44.867', 10605, 1321, 39),
(5135, 'sky is the competitor ', '2025-06-13 11:23:44.290', 10605, 1322, 51),
(5141, 'Dantra had not delivered their last order ', '2025-06-13 11:28:17.404', 10605, 1323, 21),
(5142, 'few walk-ins slow movement of products. pushing for 5dots of the flavours thy don\'t have', '2025-06-13 11:29:26.157', 10605, 1324, 35),
(5143, 'They received their order \nwell stocked ', '2025-06-13 11:31:57.238', 10605, 1325, 63),
(5148, 'Opened under new management and they need a display ', '2025-06-13 11:45:14.266', 10605, 1326, 20),
(5149, 'Wells Fargo did not provide an invoice or lpo hence the product was not received.', '2025-06-13 11:47:15.372', 10605, 1327, 23),
(5154, 'I\'ve been trying to onboard them. the boss will be around next week. I\'ll come back. ', '2025-06-13 11:50:29.307', 10605, 1328, 47),
(5157, 'we are placing another order since since last order it had expired ', '2025-06-13 11:52:20.068', 10605, 1329, 62),
(5160, 'Very slow product movement. ', '2025-06-13 11:55:32.945', 10605, 1330, 57),
(5167, 'well stocked ', '2025-06-13 12:05:35.350', 10605, 1331, 63),
(5169, 'They well stocked', '2025-06-13 12:07:19.196', 10605, 1332, 22),
(5172, 'slow moving product ', '2025-06-13 12:12:01.965', 10605, 1333, 46),
(5177, 'The owner had requested the product to be returned to the office but has not been picked.', '2025-06-13 12:30:06.517', 10605, 1334, 23),
(5179, 'very good movement ', '2025-06-13 12:35:50.046', 10605, 1335, 49),
(5181, 'placed an order for 20pcs 9000puffs', '2025-06-13 12:42:08.440', 10605, 1336, 47),
(5182, 'yet to uplift from their go down ', '2025-06-13 12:43:30.703', 10605, 1337, 49),
(5186, 'well stocked', '2025-06-13 12:46:11.174', 10605, 1338, 46),
(5187, 'well stocked on pouches and vapes ', '2025-06-13 12:46:25.481', 10605, 1339, 57),
(5189, 'to uplift from droppers ', '2025-06-13 12:48:09.962', 10605, 1340, 44),
(5193, 'They received their order ', '2025-06-13 12:52:11.657', 10605, 1341, 63),
(5196, 'will order mid month on Vapes ', '2025-06-13 12:56:13.643', 10605, 1342, 62),
(5200, 'outlet is stocked with pouches', '2025-06-13 13:06:42.630', 10605, 1343, 50),
(5202, 'to pay the pending invoice. ', '2025-06-13 13:10:34.598', 10605, 1344, 47),
(5205, 'They are complaining display is not at the Right place ', '2025-06-13 13:16:05.762', 10605, 1345, 63),
(5211, 'they have not confirmed to start stocking ', '2025-06-13 13:29:54.855', 10605, 1346, 26),
(5213, 'Very well stocked. Product is moving very slowly at this outlet. \n3000 puffs 46pcs in stock, 9000 puffs 43pcs remaining.', '2025-06-13 13:34:19.597', 10605, 1347, 57),
(5219, 'Trying to Onboard them ', '2025-06-13 14:39:14.503', 10605, 1348, 32),
(5221, 'Well stocked, products move the fastest at this outlet. ', '2025-06-13 14:42:57.116', 10605, 1349, 57),
(5222, 'only 4pcs of pouches available ', '2025-06-13 14:44:51.202', 10605, 1350, 32),
(5227, 'waiting for GP to be listed', '2025-06-13 14:55:26.771', 10605, 1351, 26),
(5229, 'Trying to Onboard them ', '2025-06-13 15:04:40.716', 10605, 1352, 32),
(5230, 'trying to Onboard them ', '2025-06-13 15:17:50.231', 10605, 1353, 32),
(5234, 'competitetor hart', '2025-06-13 15:28:53.929', 10605, 1354, 7),
(5235, 'The competitor is gogo.They will make an reorder Tomorrow. ', '2025-06-13 15:33:51.954', 10605, 1355, 51),
(5241, 'well displayed\nlow stock...but will replenish order day;next week.', '2025-06-14 06:51:50.454', 10605, 1356, 64),
(5244, 'well stocked\nwell displayed.', '2025-06-14 07:29:35.024', 10605, 1357, 64),
(5248, 'well displayed\nwell stocked.order was received.', '2025-06-14 07:36:50.097', 10605, 1358, 64),
(5249, 'following up on sale\'s ', '2025-06-14 07:44:00.558', 10605, 1359, 35),
(5251, 'Following up on stocking. ', '2025-06-14 07:51:22.097', 10605, 1360, 35),
(5252, 'yet received our product which am following it specific evening I will come back to meet internal head ', '2025-06-14 07:59:20.377', 10605, 1361, 62),
(5253, 'yet received our product which am following it specific evening I will come back to meet internal head ', '2025-06-14 07:59:41.151', 10605, 1362, 62),
(5256, 'They have enough stocks ', '2025-06-14 08:08:27.360', 10605, 1363, 21),
(5257, 'following up on stocking up. ', '2025-06-14 08:09:29.632', 10605, 1364, 35),
(5265, 'They are well stocked', '2025-06-14 08:29:49.414', 10605, 1365, 22),
(5267, 'We can\'t place any order because they have stock project going on untill Monday ', '2025-06-14 08:31:20.865', 10605, 1366, 21),
(5270, 'They will make an order tomorrow for the 3000puffs .\nGogo is the competitor. ', '2025-06-14 08:34:16.552', 10605, 1367, 51),
(5275, 'placed order today ', '2025-06-14 08:37:42.255', 10605, 1368, 62),
(5276, 'has an order to make on Monday ', '2025-06-14 08:38:04.892', 10605, 1369, 35),
(5278, 'will call next week for an order', '2025-06-14 08:52:57.598', 10605, 1370, 32),
(5285, 'The competitors are ;\nbooster rrp 820\nsky rrp 690\nhart rrp 2170,1100', '2025-06-14 09:08:02.690', 10605, 1371, 51),
(5286, 'the vapes are very slow in movement ', '2025-06-14 09:08:14.346', 10605, 1372, 26),
(5290, 'They are well stocked', '2025-06-14 09:13:17.300', 10605, 1373, 22),
(5291, 'This is new outlet to be onboard', '2025-06-14 09:13:43.817', 10605, 1374, 22),
(5293, 'The product was sealed by the county government and they are unable to sell. Reason being that they are not allowed to display.', '2025-06-14 09:21:55.117', 10605, 1375, 23),
(5297, 'well stocked ', '2025-06-14 09:25:53.722', 10605, 1376, 32),
(5299, 'Trying to Onboard them ', '2025-06-14 09:29:14.885', 10605, 1377, 32),
(5300, 'No enjoy shop', '2025-06-14 09:29:32.201', 10605, 1378, 23),
(5304, 'Display needs fixing ', '2025-06-14 09:32:41.314', 10605, 1379, 30),
(5308, 'outlet selling slow', '2025-06-14 09:36:17.848', 10605, 1380, 50),
(5314, 'the two pieces are not moving ', '2025-06-14 09:48:04.185', 10605, 1381, 39),
(5316, 'The movement is okay for the vapes not for the pouches ', '2025-06-14 09:53:10.170', 10605, 1382, 39),
(5319, 'the movement is okay ', '2025-06-14 09:58:43.944', 10605, 1383, 39),
(5321, 'no sales in the the month of May and June', '2025-06-14 11:18:05.585', 10605, 1384, 57),
(5326, '3000 puffs doing well compared to 9000 puffs', '2025-06-14 11:36:56.378', 10605, 1385, 26),
(5327, 'the stock is moving slow. ', '2025-06-14 11:36:59.594', 10605, 1386, 47),
(5332, 'Sales are being affected by low season. ', '2025-06-14 12:00:58.709', 10605, 1387, 57),
(5337, 'will place their order at the end of the month', '2025-06-14 12:13:16.819', 10605, 1388, 57),
(5341, 'pouches are moving qell', '2025-06-14 12:26:15.896', 10605, 1389, 47),
(5342, 'pouches are selling well. ', '2025-06-14 12:26:34.164', 10605, 1390, 47),
(5345, 'the GP are doing well compared to vapes', '2025-06-14 12:30:17.775', 10605, 1391, 26),
(5348, 'the manager is not around today. still pushing him to order. ', '2025-06-14 12:34:37.855', 10605, 1392, 47),
(5350, 'well stocked ', '2025-06-14 13:36:10.271', 10605, 1393, 20),
(5351, 'shared a catalogue will do get an order soon', '2025-06-14 14:13:53.129', 10605, 1394, 32),
(5353, 'well stocked \n*following up on Payments ', '2025-06-16 08:24:20.083', 10605, 1395, 7),
(5358, 'waiting for pouches  order ', '2025-06-16 09:01:28.219', 10605, 1396, 48),
(5363, 'the product is moving a bit slow', '2025-06-16 09:41:25.673', 10605, 1397, 7),
(5364, 'they have 10 PCs remaining which they say it\'s enough for them since they are moving slowly ', '2025-06-16 09:47:53.467', 10605, 1398, 7),
(5365, 'they have 10 PCs remaining which they say it\'s enough for them since they are moving slowly ', '2025-06-16 09:56:24.770', 10605, 1399, 7),
(5368, 'pushing  forya pouches coz haha\nbut amenishow nimpe mpaka Wednesday ', '2025-06-16 10:03:27.099', 10605, 1400, 48),
(5370, 'no complain so far ', '2025-06-16 10:17:52.088', 10605, 1401, 7),
(5374, 'customers are still coming and increasing slowly ', '2025-06-16 10:23:20.063', 10605, 1402, 48),
(5378, 'pushing for pouches order ', '2025-06-16 10:44:05.899', 10605, 1403, 48),
(5385, 'received the order ', '2025-06-16 10:55:37.067', 10605, 1404, 48),
(5390, 'will make tomorrow ', '2025-06-16 11:21:22.640', 10605, 1405, 48),
(5399, 'we are working on an order today ', '2025-06-16 11:41:47.573', 10605, 1406, 35),
(5400, 'The manager is requesting to return 3dots pouches in exchange for 5 dots or vapes since 3dots pouches are not moving. ', '2025-06-16 11:42:07.263', 10605, 1407, 47),
(5402, 'well stocked\nwell displayed.', '2025-06-16 11:42:42.079', 10605, 1408, 64),
(5406, 'order placed. to be delivered today but it was own collection ', '2025-06-16 11:46:46.384', 10605, 1409, 47),
(5410, 'pushing for a restock ', '2025-06-16 11:49:16.164', 10605, 1410, 39),
(5416, 'well stocked.order was received\nwell displayed.', '2025-06-16 11:57:25.156', 10605, 1411, 64),
(5422, 'following up on an order ', '2025-06-16 12:03:13.296', 10605, 1412, 35),
(5426, 'will order 9000puffs next weeek', '2025-06-16 12:11:26.356', 10605, 1413, 32),
(5429, 'the clients do not want our products due to our packaging ', '2025-06-16 12:17:04.830', 10605, 1414, 39),
(5431, 'pushing for a restock ', '2025-06-16 12:24:11.366', 10605, 1415, 39),
(5440, 'Getting their remaining stock 5 pieces ', '2025-06-16 12:29:28.759', 10605, 1416, 49),
(5445, 'Not placed an order ', '2025-06-16 12:34:58.851', 10605, 1417, 91),
(5446, 'well stocked\nwell displayed\nmovement:slow', '2025-06-16 12:35:23.031', 10605, 1418, 64),
(5449, 'they\'re well stocked and trying to push the products though selling under the counter ', '2025-06-16 12:37:05.344', 10605, 1419, 21),
(5458, 'Returned products back to shelves. Still well stocked on all SKUs.', '2025-06-16 13:41:20.790', 10605, 1420, 57),
(5462, 'Well stocked on all SKUs. Payments on pending debts will be cleared before end of June. ', '2025-06-16 13:48:27.480', 10605, 1421, 57),
(5463, 'the shop was still closed on arrival. Following up on a call. ', '2025-06-16 13:53:03.939', 10605, 1422, 35),
(5464, 'persuading the outlet on stocking. making follow up', '2025-06-16 14:02:17.111', 10605, 1423, 35),
(5468, 'vapes are selling slow. ', '2025-06-16 14:09:55.946', 10605, 1424, 47),
(5470, 'to order this week', '2025-06-16 14:19:06.634', 10605, 1425, 47),
(5475, 'Following up on payments. ', '2025-06-16 14:29:18.401', 10605, 1426, 57),
(5477, 'The owner rejectes our products but I\'ll still persue them with the help of the attendant', '2025-06-16 14:39:43.505', 10605, 1427, 23),
(5478, 'To process order after payment ', '2025-06-16 14:47:47.643', 10605, 1428, 30),
(5479, 'waiting for pouches from BLUESKY main ', '2025-06-16 14:58:52.527', 10605, 1429, 32),
(5481, 'to pay the pending invoices. ', '2025-06-16 15:02:53.371', 10605, 1430, 47),
(5484, 'to place their order tomorrow ', '2025-06-16 15:28:12.547', 10605, 1431, 57),
(5488, 'the movement is very slow ', '2025-06-17 06:25:29.781', 10605, 1432, 39),
(5490, 'to see if they will place an order for gold pouches soon. ', '2025-06-17 06:30:44.606', 10605, 1433, 12),
(5493, 'the vapes are very slow', '2025-06-17 06:51:53.463', 10605, 1434, 26),
(5498, 'well stocked both 3k and 9k vapes\nwell dislayed\norder was delivered\n', '2025-06-17 07:10:27.677', 10605, 1435, 64),
(5499, 'normally share with Rubis zetech which is chaired by one manager so we are placing order at other side of Rubis zetech for the two to share ', '2025-06-17 07:11:13.146', 10605, 1436, 62),
(5501, 'the BA is really much needed to push the stock ', '2025-06-17 07:14:30.045', 10605, 1437, 39),
(5505, '9k puffs @3000/= and 3k puffs @2300/=\nGP @650/=\nwell displayed\nwell stocked\nmovement:slow', '2025-06-17 07:17:45.652', 10605, 1438, 64),
(5508, 'low stock\nmanagement says they wont add because they are moving slow', '2025-06-17 07:27:14.208', 10605, 1439, 64),
(5512, 'test', '2025-06-17 07:38:09.916', 10605, 1440, 94),
(5522, 'well stocked in 3k and GP\nVapes not moving\nGP moving \nwell displayed.', '2025-06-17 07:44:04.425', 10605, 1441, 64),
(5523, '20pcs gold pouches received. ', '2025-06-17 07:46:01.359', 10605, 1442, 47),
(5526, 'so far no sales in the last few weeks ', '2025-06-17 07:51:39.608', 10605, 1443, 35),
(5527, 'trying to onboard them ', '2025-06-17 07:55:13.787', 10605, 1444, 39),
(5533, 'low on stock\norder wasnt delivered due to pending payments.\nhere to follow up on the same.', '2025-06-17 07:57:51.041', 10605, 1445, 64),
(5537, 'following up with payments for last order', '2025-06-17 08:13:46.172', 10605, 1446, 17),
(5538, 'following up on boarding the outlet. I believe it\'s a potential however much the client is not ready to stock up ', '2025-06-17 08:14:07.545', 10605, 1447, 35),
(5540, 'Placed a small order', '2025-06-17 08:15:12.278', 10605, 1448, 30),
(5544, 'placed order last week still not arrived ', '2025-06-17 08:17:33.212', 10605, 1449, 62),
(5550, 'we still have vapes for January very slow moving ', '2025-06-17 08:30:43.397', 10605, 1450, 20),
(5554, 'cheque collected ', '2025-06-17 08:33:20.492', 10605, 1451, 57),
(5559, 'kuko slow ', '2025-06-17 08:38:19.941', 10605, 1452, 48),
(5560, 'still stocked up ', '2025-06-17 08:42:05.661', 10605, 1453, 35),
(5563, 'follow up on stocking ', '2025-06-17 08:48:09.694', 10605, 1454, 35),
(5565, 'Pushing for both the payment and a reorder ', '2025-06-17 08:48:37.737', 10605, 1455, 49),
(5567, 'placed their order', '2025-06-17 08:55:41.629', 10605, 1456, 57),
(5578, 'Fair movement \nExpecting an order from next week', '2025-06-17 09:02:59.621', 10605, 1457, 49),
(5583, 'the movement is okay ', '2025-06-17 09:04:57.346', 10605, 1458, 39),
(5585, 'stock movement okay ', '2025-06-17 09:05:56.429', 10605, 1459, 35),
(5586, 'They\'re well stocked ', '2025-06-17 09:06:08.965', 10605, 1460, 21),
(5595, 'I have dropped the display at the outlet ', '2025-06-17 09:13:31.533', 10605, 1461, 23),
(5600, 'Everything is okay ', '2025-06-17 09:16:46.544', 10605, 1462, 21),
(5601, 'for vapes they are not still willing to stock ', '2025-06-17 09:17:08.435', 10605, 1463, 35),
(5604, 'Movement improvement has been noticed ', '2025-06-17 09:21:15.047', 10605, 1464, 49),
(5613, 'They well stocked', '2025-06-17 09:36:54.255', 10605, 1465, 22),
(5619, 'placed order yesterday enough to run this month ', '2025-06-17 09:39:50.175', 10605, 1466, 62),
(5620, 'well stocked but vapes moving slowly ', '2025-06-17 09:39:58.553', 10605, 1467, 63),
(5623, 'products are moving slow due to the ongoing renovations', '2025-06-17 09:42:05.715', 10605, 1468, 50),
(5630, 'not yet received their order ', '2025-06-17 09:53:24.496', 10605, 1469, 63),
(5634, 'they are well stockrd', '2025-06-17 09:56:15.815', 10605, 1470, 22),
(5640, 'well stocked up ', '2025-06-17 10:12:01.211', 10605, 1471, 63),
(5645, 'the movement is slow ', '2025-06-17 10:20:30.068', 10605, 1472, 39),
(5653, 'working on paying the pending invoice.Pouches are doing well in the outlet ', '2025-06-17 10:29:38.840', 10605, 1473, 23),
(5656, 'They have no enough stock and they\'re not placing orders because the shop will be closed by the end of this week. ', '2025-06-17 10:34:02.111', 10605, 1474, 21),
(5659, 'Stocks movement is very slow ', '2025-06-17 10:43:49.464', 10605, 1475, 30),
(5662, 'placed an order ', '2025-06-17 10:46:37.164', 10605, 1476, 7),
(5664, 'the movement is okay ', '2025-06-17 10:47:55.956', 10605, 1477, 39),
(5666, 'They are well stocked', '2025-06-17 10:48:51.398', 10605, 1478, 22),
(5674, 'The movement is very low', '2025-06-17 11:09:43.317', 10605, 1479, 22),
(5682, 'waiting on stock arrival from the office ', '2025-06-17 11:19:50.948', 10605, 1480, 35),
(5689, 'movement improvement \nexpecting am order in the course of the month ', '2025-06-17 11:30:13.159', 10605, 1481, 49),
(5693, 'pushing for reorder ', '2025-06-17 11:33:30.861', 10605, 1482, 48),
(5695, 'They are well stocked', '2025-06-17 11:34:44.532', 10605, 1483, 22),
(5697, 'will place order on Tuesday next week ', '2025-06-17 11:44:26.471', 10605, 1484, 62),
(5699, 'waiting for pending delivery ', '2025-06-17 11:47:43.450', 10605, 1485, 26),
(5702, 'The attendant are also pushing the manager to make payments for the pending invoice.', '2025-06-17 11:50:25.654', 10605, 1486, 23),
(5704, 'The movement is okay ', '2025-06-17 11:53:06.270', 10605, 1487, 39),
(5707, 'kumetulia', '2025-06-17 11:55:44.805', 10605, 1488, 48),
(5708, 'The manager was absent and the counter told me to come next time ', '2025-06-17 11:56:03.880', 10605, 1489, 68),
(5710, 'They\'re not selling any kind of cigarettes ', '2025-06-17 12:05:01.434', 10605, 1490, 68),
(5714, 'The manager is currently not selling it but promised to call me when he establishes shisha gang', '2025-06-17 12:11:53.277', 10605, 1491, 68),
(5716, 'the movement is slow ', '2025-06-17 12:12:12.479', 10605, 1492, 39),
(5722, 'slow moving ', '2025-06-17 12:19:29.011', 10605, 1493, 62),
(5724, 'The movement is slow ', '2025-06-17 12:20:34.579', 10605, 1494, 39),
(5729, 'They are well stocked', '2025-06-17 12:27:14.160', 10605, 1495, 22),
(5732, 'no stock.\nwaiting for payment then make an order ', '2025-06-17 12:30:59.530', 10605, 1496, 49),
(5735, 'Not ordering atthe moment ', '2025-06-17 12:36:06.430', 10605, 1497, 30),
(5739, 'They\'re well stocked ', '2025-06-17 12:39:05.177', 10605, 1498, 21),
(5742, 'procurement officer not in but has agreed to pay when she gets back', '2025-06-17 12:51:18.610', 10605, 1499, 44),
(5751, 'to pay the pending invoices ', '2025-06-17 13:12:41.479', 10605, 1500, 47),
(5754, 'Stocks moving slowly. Currently have 16pcs 3000 puffs in stock. ', '2025-06-17 13:19:18.923', 10605, 1501, 57),
(5761, 'considering on stocking vapes', '2025-06-17 13:27:31.239', 10605, 1502, 47),
(5762, 'not stocked in all skus', '2025-06-17 13:28:07.354', 10605, 1503, 26),
(5770, 'the vapes are very slow', '2025-06-17 13:50:43.127', 10605, 1504, 26),
(5776, 'Well stocked. Clearing pending payments before end of June', '2025-06-17 14:28:58.024', 10605, 1505, 57),
(5777, 'Hart is selling than our vapes but our pouches are doing well', '2025-06-17 14:31:09.387', 10605, 1506, 20),
(5779, 'The display need# mounting ', '2025-06-17 14:34:59.736', 10605, 1507, 30),
(5780, 'fair movement ', '2025-06-17 14:40:36.122', 10605, 1508, 49),
(5785, 'well stocked ', '2025-06-17 15:56:55.730', 10605, 1509, 20),
(5787, 'order placed. ', '2025-06-17 16:11:06.982', 10605, 1510, 47),
(5788, 'still stocked ', '2025-06-17 16:19:37.063', 10605, 1511, 20),
(5790, 'we\'re meeting with the manager today. ', '2025-06-18 06:47:48.748', 10605, 1512, 47),
(5796, 'well displayed\nwell stocked both 9k and 3k.', '2025-06-18 07:19:44.896', 10605, 1513, 64),
(5799, 'I have an order for 20pcs vapes but the flavours are not available. I\'m trying to convince him to pick what is available. ', '2025-06-18 07:38:20.597', 10605, 1514, 47),
(5804, 'closed', '2025-06-18 07:42:00.745', 10605, 1515, 17),
(5808, 'They\'re well stocked ', '2025-06-18 07:45:39.629', 10605, 1516, 21),
(5809, 'Not ordering at the moment... ', '2025-06-18 07:49:37.982', 10605, 1517, 30),
(5812, 'made an order but has not been delivered ', '2025-06-18 08:01:49.225', 10605, 1518, 73),
(5816, 'well stocked on 3k puffs\n9k puffs low...will ask for reorder.\n', '2025-06-18 08:10:31.570', 10605, 1519, 64),
(5821, 'pouches are more faster moving ', '2025-06-18 08:15:34.733', 10605, 1520, 62),
(5824, 'we are placing order', '2025-06-18 08:22:39.933', 10605, 1521, 22),
(5828, 'we\'ll make an order next Monday ', '2025-06-18 08:31:28.544', 10605, 1522, 73),
(5836, 'well stocked with both 9k and 3k puffs\nrrp @1570 and @2000\nGP not listed.', '2025-06-18 08:45:43.430', 10605, 1523, 64),
(5838, 'Well stocked. maybe to place order next week ', '2025-06-18 08:47:09.077', 10605, 1524, 21),
(5852, 'Stocked', '2025-06-18 09:16:52.279', 10605, 1525, 20),
(5857, 'stocked in 3k puffs and GP\nRRP @500 For GP and @1570 for 3000 puffs.', '2025-06-18 09:22:12.901', 10605, 1526, 64),
(5860, 'well stocked ', '2025-06-18 09:24:30.996', 10605, 1527, 63),
(5864, 'They are well stocked', '2025-06-18 09:28:48.754', 10605, 1528, 22),
(5871, 'the outlet is well stocked up with all skus', '2025-06-18 09:36:58.983', 10605, 1529, 26),
(5881, 'Follow-up to see if the cheque was pick and also now if the stock arrived ', '2025-06-18 09:49:15.454', 10605, 1530, 40),
(5885, 'Not sold in a week\'s time now', '2025-06-18 09:55:34.587', 10605, 1531, 35),
(5886, 'well stocked for now ', '2025-06-18 09:56:02.045', 10605, 1532, 7),
(5895, 'not yet received their order ', '2025-06-18 10:06:05.246', 10605, 1533, 63),
(5899, 'A potential client, Engaging management ', '2025-06-18 10:10:30.308', 10605, 1534, 49),
(5907, 'pouches have picked and the requested flavours ordered', '2025-06-18 10:16:24.724', 10605, 1535, 44),
(5909, 'will pay pending bill this week ', '2025-06-18 10:18:29.957', 10605, 1536, 62),
(5911, 'following up on boarding them and order ', '2025-06-18 10:19:00.779', 10605, 1537, 35),
(5913, 'Arranged the received order', '2025-06-18 10:19:48.907', 10605, 1538, 30),
(5921, 'outlet selling slow \nNo competitor', '2025-06-18 10:25:42.136', 10605, 1539, 50),
(5923, 'there\'s a pending order they have just waiting on clarification from the manager ', '2025-06-18 10:28:40.089', 10605, 1540, 35),
(5931, 'exchange needed at Naivas roosters', '2025-06-18 10:43:50.791', 10605, 1541, 63),
(5933, 'exchange of Vapes needed at Naivas roosters ', '2025-06-18 10:44:18.490', 10605, 1542, 63),
(5937, 'Stock arrived with out the display ', '2025-06-18 11:03:00.390', 10605, 1543, 40),
(5939, 'well stocked ', '2025-06-18 11:04:05.004', 10605, 1544, 63),
(5945, 'pushing for payment so as we can reorder ', '2025-06-18 11:06:46.589', 10605, 1545, 48),
(5947, 'pushing for payment ', '2025-06-18 11:14:24.918', 10605, 1546, 49),
(5950, 'pushing ', '2025-06-18 11:16:38.470', 10605, 1547, 48),
(5951, 'Follow-up for order ', '2025-06-18 11:17:12.974', 10605, 1548, 40),
(5952, 'pushing for reorder ', '2025-06-18 11:17:22.058', 10605, 1549, 48),
(5957, 'vapes moving slowly ', '2025-06-18 11:19:46.355', 10605, 1550, 63),
(5958, 'they had ordered their first time this month but but kiambu government is threatening always so are not displaying and customer have no awareness of the product ', '2025-06-18 11:21:21.440', 10605, 1551, 62),
(5962, 'the movement is okay \ncooling mint is selling than the citrus ', '2025-06-18 11:28:50.013', 10605, 1552, 39),
(5971, 'outlet selling slowly,,,hence no competitor', '2025-06-18 11:43:05.338', 10605, 1553, 50),
(5973, 'movement is very slow ', '2025-06-18 11:44:37.470', 10605, 1554, 39),
(5977, 'well stocked \nThey received their order ', '2025-06-18 11:50:08.425', 10605, 1555, 63),
(5979, 'well stocked', '2025-06-18 11:56:27.239', 10605, 1556, 26),
(5983, 'the movement is slow than usual ', '2025-06-18 11:58:24.865', 10605, 1557, 39),
(5987, 'done stocking woosh', '2025-06-18 12:02:41.462', 10605, 1558, 49),
(5990, 'Well stocked and pushing hard ', '2025-06-18 12:03:48.114', 10605, 1559, 21),
(5993, 'following up with payments,stock is moving well', '2025-06-18 12:06:00.058', 10605, 1560, 17),
(5994, 'expecting a reorder before the end of the month ', '2025-06-18 12:09:20.875', 10605, 1561, 39),
(5999, 'made payments ', '2025-06-18 12:29:18.187', 10605, 1562, 48),
(6003, 'outlet improving', '2025-06-18 12:43:06.341', 10605, 1563, 50),
(6006, 'pushing for the pending payment ', '2025-06-18 12:45:41.744', 10605, 1564, 39),
(6011, 'outlet selling too slow', '2025-06-18 12:48:22.915', 10605, 1565, 50),
(6013, 'pushing the client to pay the pending invoice. ', '2025-06-18 12:50:01.498', 10605, 1566, 47);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(6015, 'have 17 pcs za gogo', '2025-06-18 12:51:27.115', 10605, 1567, 48),
(6019, 'orders are not being delivered ', '2025-06-18 12:56:49.110', 10605, 1568, 26),
(6026, 'Still awaiting their order. ', '2025-06-18 13:05:23.952', 10605, 1569, 57),
(6030, 'have enough stock ', '2025-06-18 13:13:27.855', 10605, 1570, 62),
(6035, 'to place an order by the end of the day or tomorrow. ', '2025-06-18 13:18:38.354', 10605, 1571, 47),
(6040, 'Very well stocked. To clear pending payments by end of June. ', '2025-06-18 13:23:57.753', 10605, 1572, 57),
(6046, 'manager not avaible ', '2025-06-18 13:33:54.271', 10605, 1573, 69),
(6057, 'order was self pick up. ', '2025-06-18 13:42:44.397', 10605, 1574, 47),
(6061, 'Products have been put back for display. Vape sales are slowly increasing. ', '2025-06-18 13:46:30.097', 10605, 1575, 57),
(6064, 'Movements still slow', '2025-06-18 13:51:09.195', 10605, 1576, 30),
(6067, 'trying to onboard them. ', '2025-06-18 13:59:30.472', 10605, 1577, 47),
(6069, 'Very well stocked on 3000 puffs. Will not be ordering this month. ', '2025-06-18 14:02:39.518', 10605, 1578, 57),
(6077, '3 dots are very slow', '2025-06-18 14:07:15.381', 10605, 1579, 26),
(6080, 'They told me to come next week ', '2025-06-18 14:14:05.308', 10605, 1580, 68),
(6081, 'The outlet is under renovation and doesn\'t have any of our products at the moment ', '2025-06-18 14:15:53.517', 10605, 1581, 30),
(6084, 'They loved it and told me to come next time ', '2025-06-18 14:21:36.883', 10605, 1582, 68),
(6086, 'Following up on expected order date. ', '2025-06-18 14:41:41.370', 10605, 1583, 57),
(6087, 'Still under discusion ', '2025-06-18 15:01:07.804', 10605, 1584, 69),
(6088, 'well stocked moving slowly ', '2025-06-18 15:45:36.762', 10605, 1585, 40),
(6094, 'Already received their order ', '2025-06-19 07:17:13.373', 10605, 1586, 73),
(6095, 'They placed an order for 20 pieces of vapes.\nThe competitor is gogo. \nit has mint ice,Pinacolada, strawberry kiwi,cola lime as the flavours in the market. \nThe rrp is 3300 for 16000puffs and ', '2025-06-19 07:18:00.963', 10605, 1587, 51),
(6101, 'Only a piece sold in a week. ', '2025-06-19 07:48:27.555', 10605, 1588, 35),
(6111, 'They received  a new reorder from dantra.', '2025-06-19 07:59:21.330', 10605, 1589, 51),
(6112, 'following up on a reorder from them, still not in a position to place an order citing low customer turn out', '2025-06-19 08:01:45.413', 10605, 1590, 35),
(6119, 'had placed order but haven\'t received ', '2025-06-19 08:12:20.179', 10605, 1591, 62),
(6121, 'Following up for boarding but still insist unless Magnum lounge stock\'s up they can\'t also. Will reach out to Magnum\'s manager over the same ', '2025-06-19 08:15:40.361', 10605, 1592, 35),
(6122, 'They will place an order for vapes next week', '2025-06-19 08:15:49.319', 10605, 1593, 23),
(6126, 'the vapes are very slow in movement ', '2025-06-19 08:16:57.238', 10605, 1594, 26),
(6133, 'well stocked ', '2025-06-19 08:23:27.036', 10605, 1595, 63),
(6134, 'well stocked with 3k....9k puffs low on stock\nwell displayed...', '2025-06-19 08:27:39.147', 10605, 1596, 64),
(6137, 'well stocked following up with payments ', '2025-06-19 08:29:52.145', 10605, 1597, 17),
(6141, 'received their order ', '2025-06-19 08:33:15.914', 10605, 1598, 73),
(6150, 'slow movement of the product. ', '2025-06-19 08:43:13.903', 10605, 1599, 47),
(6158, 'we placed order last week but still not arrived ', '2025-06-19 08:45:52.948', 10605, 1600, 62),
(6159, 'vapes slow movement ', '2025-06-19 08:46:08.096', 10605, 1601, 26),
(6167, 'Low sales after the display was removed from the front. Item\'s not Visible promptly ', '2025-06-19 08:54:32.560', 10605, 1603, 35),
(6172, 'placing an order for 5dots before week ends ', '2025-06-19 08:56:41.723', 10605, 1604, 63),
(6176, 'made an order last week and was received ', '2025-06-19 08:59:20.370', 10605, 1605, 73),
(6184, 'gogo is the competitor  with\nblueberry ice,strawberry ice,Pinacolada, strawberry kiwi,minty ice being their flavours.\n10000puffs  rrp 2500\n16000puffs  rrp 3300\nThe 9000puffs are slow moving.\n', '2025-06-19 09:05:47.679', 10605, 1606, 51),
(6186, 'They placed and received their order.', '2025-06-19 09:07:17.548', 10605, 1607, 23),
(6192, 'They are well stocked', '2025-06-19 09:13:45.633', 10605, 1608, 22),
(6197, 'well stocked \nwell displayed...GP rrp @550 and 3k puffs rrp @1570', '2025-06-19 09:15:52.052', 10605, 1609, 64),
(6198, 'sale\'s movement okay', '2025-06-19 09:17:25.992', 10605, 1610, 35),
(6200, 'its a potential client that I\'m trying to onboard ', '2025-06-19 09:22:07.355', 10605, 1611, 39),
(6202, 'potential client for pouches that I\'m trying to onboard ', '2025-06-19 09:25:20.254', 10605, 1612, 39),
(6208, 'no sales in a month ', '2025-06-19 09:32:23.799', 10605, 1613, 35),
(6211, 'They have not sold anything from their last order.', '2025-06-19 09:34:34.927', 10605, 1614, 23),
(6214, 'well stocked but we\'ve placed order for the sold out flavors ', '2025-06-19 09:41:49.250', 10605, 1615, 21),
(6215, 'closed ', '2025-06-19 09:42:13.618', 10605, 1616, 20),
(6218, 'we are placing order tommorrow', '2025-06-19 09:44:22.380', 10605, 1617, 22),
(6220, 'they have our products\nand like ', '2025-06-19 09:44:58.485', 10605, 1618, 70),
(6222, 'new client trying to onboard them', '2025-06-19 09:53:15.426', 10605, 1620, 7),
(6230, 'Display awaiting to be mounted ', '2025-06-19 09:58:26.906', 10605, 1621, 30),
(6232, 'They are well stocked', '2025-06-19 09:59:58.721', 10605, 1622, 22),
(6233, 'well stocked,not allowed to take photos', '2025-06-19 10:00:01.154', 10605, 1623, 17),
(6236, 'will make a reorder  on Saturday ', '2025-06-19 10:01:50.337', 10605, 1624, 48),
(6239, 'low on 3k puffs but stocked in 9k puffs and GP\nsaid they would restock after available products move.', '2025-06-19 10:06:26.192', 10605, 1625, 64),
(6255, 'it\'s been slaw ', '2025-06-19 10:17:54.370', 10605, 1626, 48),
(6258, 'They are well stocked', '2025-06-19 10:18:49.775', 10605, 1627, 22),
(6259, 'slow uptake of our products.\n', '2025-06-19 10:20:41.216', 10605, 1628, 44),
(6261, 'The vapes are currently bring sold under the counter.The competitor is hart.', '2025-06-19 10:22:53.358', 10605, 1629, 51),
(6266, 'They received their order ', '2025-06-19 10:29:58.964', 10605, 1630, 63),
(6267, 'The manager was not avaible but still need some time ', '2025-06-19 10:30:43.161', 10605, 1631, 69),
(6272, 'They have placed a new order for vapes and Pouches ', '2025-06-19 10:33:42.751', 10605, 1632, 23),
(6277, 'order not received ', '2025-06-19 10:36:42.585', 10605, 1633, 62),
(6279, 'made payments ', '2025-06-19 10:38:38.234', 10605, 1634, 48),
(6282, 'They are not allowed to display the product. This directive was given by the owner.', '2025-06-19 10:47:14.411', 10605, 1635, 23),
(6284, 'Hart on yhe process of introducing new pouches', '2025-06-19 10:48:02.962', 10605, 1636, 30),
(6295, 'Fair movement of pouches ', '2025-06-19 11:05:14.827', 10605, 1637, 49),
(6300, 'outlet improving on sales', '2025-06-19 11:06:18.638', 10605, 1638, 50),
(6310, 'They are still well stocked', '2025-06-19 11:12:36.575', 10605, 1639, 22),
(6315, 'Extremely slow movement ', '2025-06-19 11:14:25.929', 10605, 1640, 49),
(6316, 'received their order still ', '2025-06-19 11:14:29.532', 10605, 1641, 62),
(6317, 'made an order ', '2025-06-19 11:14:47.942', 10605, 1642, 48),
(6324, 'fair movement ', '2025-06-19 11:24:08.892', 10605, 1643, 49),
(6328, 'Well stocked on vapes. Placing their order for pouches this week. ', '2025-06-19 11:27:45.152', 10605, 1644, 57),
(6334, 'fair movement ', '2025-06-19 11:30:12.018', 10605, 1645, 49),
(6335, 'outlet stocked ,,,stock moving slow ,,lack of display to display the pouches ', '2025-06-19 11:30:20.229', 10605, 1646, 50),
(6345, 'product not yet received in the outlet ', '2025-06-19 11:42:15.958', 10605, 1647, 23),
(6346, 'supervisor is absent until tomorrow ', '2025-06-19 11:43:08.248', 10605, 1648, 62),
(6353, 'Product is performing poorly at this outlet. Sold only 2pcs since last order on 29th April. Payment processing has been a challenge with owner having travelled since May. ', '2025-06-19 12:03:00.522', 10605, 1649, 57),
(6356, 'they show interest to have our products ', '2025-06-19 12:05:32.240', 10605, 1651, 70),
(6357, 'They have made reorder on the pouches which they have currently received. ', '2025-06-19 12:06:38.299', 10605, 1652, 51),
(6361, 'slow moving since from last week only one pouch sold, zero vapes ', '2025-06-19 12:14:18.388', 10605, 1653, 62),
(6365, 'well stocked ', '2025-06-19 12:17:52.385', 10605, 1654, 21),
(6371, 'Slow movement ', '2025-06-19 12:23:55.272', 10605, 1655, 49),
(6373, 'pushing for a restock of pouches ', '2025-06-19 12:26:53.060', 10605, 1656, 39),
(6378, 'pouches order placed waiting for delivery ', '2025-06-19 12:53:59.846', 10605, 1658, 20),
(6381, 'like our products ', '2025-06-19 12:55:17.587', 10605, 1659, 70),
(6385, 'Gogo is the competitor. The minty snow is on demand.', '2025-06-19 13:04:42.740', 10605, 1660, 51),
(6388, 'They\'ve not displayed the products yet. ', '2025-06-19 13:12:04.119', 10605, 1661, 21),
(6390, 'no stocks at all', '2025-06-19 13:14:07.709', 10605, 1662, 26),
(6393, 'the vapes are very slow', '2025-06-19 13:47:20.161', 10605, 1663, 26),
(6397, 'Still very well stocked. Product moves very slowly at this outlet as it is located in a low income area. ', '2025-06-19 14:00:35.902', 10605, 1664, 57),
(6403, 'placed an order for 10pcs 3000puffs.', '2025-06-19 14:47:42.925', 10605, 1665, 47),
(6407, 'They gave me the number of manager i should contant her first about the product.', '2025-06-19 15:19:34.158', 10605, 1666, 69),
(6411, 'pushing for 3k order', '2025-06-19 15:44:17.982', 10605, 1667, 48),
(6414, 'tf', '2025-06-19 17:41:10.507', 10605, 1668, 94),
(6416, 'I have the client\'s order but he still isn\'t convinced into stocking the available flavours. 9k puffs. ', '2025-06-20 07:15:36.238', 10605, 1669, 47),
(6422, 'Will pay the pending invoices tomorrow on Saturday. ', '2025-06-20 07:35:57.459', 10605, 1670, 47),
(6425, 'we\'ll stocked moving well to', '2025-06-20 07:41:31.542', 10605, 1671, 40),
(6433, 'The pouches are moving quickly.', '2025-06-20 08:02:27.002', 10605, 1672, 51),
(6438, 'Will  order once they cleared their payment', '2025-06-20 08:05:00.497', 10605, 1673, 30),
(6442, 'well stocked ', '2025-06-20 08:18:02.209', 10605, 1674, 7),
(6444, 'checked in to place a sticker on the display. ', '2025-06-20 08:19:39.041', 10605, 1675, 35),
(6447, 'They successfully received their order ', '2025-06-20 08:21:51.229', 10605, 1676, 73),
(6452, 'they haven\'t payment the debt with dantra that\'s why are \nunanable to order ', '2025-06-20 08:40:08.768', 10605, 1677, 62),
(6456, 'like our products ', '2025-06-20 08:42:21.717', 10605, 1678, 70),
(6462, 'moving slowly ', '2025-06-20 08:44:51.406', 10605, 1679, 63),
(6466, 'proposed another order but will be send from Monday next week', '2025-06-20 08:45:24.803', 10605, 1680, 36),
(6469, 'well stocked\nwell displayed\norder was received.', '2025-06-20 08:46:27.361', 10605, 1682, 64),
(6470, 'they have a broken display working on replacement once we have them', '2025-06-20 08:46:27.658', 10605, 1683, 35),
(6471, 'cooling mint has taken ground here at magunas Dallas.\nto place order on monday', '2025-06-20 08:47:37.345', 10605, 1684, 44),
(6472, 'contacted the owner owner, requested I check in at 5 for a possible order of 10pcs for a start and make payment in a week\'s time', '2025-06-20 08:55:35.694', 10605, 1685, 35),
(6474, 'they received the products without the display ', '2025-06-20 09:20:21.459', 10605, 1686, 40),
(6475, 'not yet received their order ', '2025-06-20 09:28:07.350', 10605, 1687, 63),
(6479, 'nice sales ', '2025-06-20 09:31:16.831', 10605, 1689, 70),
(6481, '9000 puffs have specific flavors for their customers which we are out of stock \nsince we had ordered before and failed to come because it\'s out of stock ', '2025-06-20 09:32:11.605', 10605, 1690, 62),
(6483, '*delivered 10pcs pouches \n*To place order for vapes tomorrow ', '2025-06-20 09:32:44.512', 10605, 1691, 7),
(6484, 'following up with the director who keeps asking me to check on him later on. ', '2025-06-20 09:33:06.823', 10605, 1692, 35),
(6485, 'Following up with Stella on stocking up as a key account, they are one of the main  distributors ', '2025-06-20 09:38:26.912', 10605, 1693, 35),
(6488, 'well stocked\nwell displayed...rrp @1570 and @2000\nmovement:slow but steady.', '2025-06-20 09:46:07.566', 10605, 1694, 64),
(6494, '* to place order next week for vapes', '2025-06-20 10:00:33.164', 10605, 1695, 7),
(6495, 'Display mounted ', '2025-06-20 10:07:15.928', 10605, 1696, 23),
(6499, 'not good sales ', '2025-06-20 10:10:40.922', 10605, 1697, 70),
(6504, 'well stocked for now ', '2025-06-20 10:11:57.792', 10605, 1699, 7),
(6508, 'well stocked ', '2025-06-20 10:15:38.010', 10605, 1700, 63),
(6510, 'well stocked in 3k and 9k puffs\nwill order GP once vapes move-from management\nmovement:slow', '2025-06-20 10:17:46.464', 10605, 1701, 64),
(6514, 'hart is the competitor rrp 1800 for rechargeable and 1000 for the non rechargeable. \nThey are well stocked .', '2025-06-20 10:24:04.390', 10605, 1702, 51),
(6516, 'fair movement ', '2025-06-20 10:30:12.845', 10605, 1703, 49),
(6519, 'No current stock\nTo collect cheque later in the evening today ', '2025-06-20 10:35:44.366', 10605, 1704, 49),
(6522, 'well stocked ', '2025-06-20 10:48:57.797', 10605, 1705, 63),
(6528, 'Hart is the competitor.\nThe prices for the vapes are 2170 and 1100 for the rechargeable and non rechargeable  vapes.', '2025-06-20 11:02:21.356', 10605, 1707, 51),
(6529, 'not good ', '2025-06-20 11:02:40.139', 10605, 1708, 70),
(6531, 'here for debt collection ', '2025-06-20 11:09:22.101', 10605, 1709, 39),
(6533, 'pushing for payment ', '2025-06-20 11:11:35.197', 10605, 1710, 48),
(6534, 'No current stock. \nAlready made an order', '2025-06-20 11:21:54.956', 10605, 1711, 49),
(6536, 'they didn\'t receive their whole order ', '2025-06-20 11:29:49.048', 10605, 1712, 62),
(6543, 'They are moving quickly in the market. ', '2025-06-20 11:51:36.041', 10605, 1714, 51),
(6546, 'pushing for payment since they are almost out of stock ', '2025-06-20 12:02:15.902', 10605, 1715, 39),
(6548, 'To collect Cheque next week so we can make another order ', '2025-06-20 12:04:03.341', 10605, 1716, 49),
(6549, 'They are to place an order for the stocked out pouches ', '2025-06-20 12:04:04.145', 10605, 1717, 23),
(6551, 'their order was received now have all the flavors ', '2025-06-20 12:14:32.144', 10605, 1718, 62),
(6552, 'Yet to place an order with Titus Finance ', '2025-06-20 12:14:51.323', 10605, 1719, 23),
(6553, 'potential client trying to onboard them ', '2025-06-20 12:17:00.006', 10605, 1720, 39),
(6554, 'potential client trying to onboard them ', '2025-06-20 12:26:28.697', 10605, 1721, 39),
(6563, 'display mounting they will asign a space once the display arrives', '2025-06-20 12:41:36.765', 10605, 1722, 62),
(6565, '3k puff is being  sold @2200 that why it\'s  slaw moving  at rubis', '2025-06-20 13:03:54.702', 10605, 1723, 48),
(6567, 'still under SoR ', '2025-06-20 13:04:56.176', 10605, 1724, 23),
(6569, 'selling at 2200 3k vape ', '2025-06-20 13:09:33.702', 10605, 1725, 48),
(6573, 'good sales ', '2025-06-20 13:19:00.414', 10605, 1727, 70),
(6574, 'Following up with Raphine the manager on stocking up', '2025-06-20 14:14:48.993', 10605, 1728, 35),
(6576, 'hart is the competitor.', '2025-06-20 15:57:51.797', 10605, 1729, 51),
(6579, 'received the order ', '2025-06-20 16:10:45.127', 10605, 1730, 48),
(6582, 'pushing for vape order ', '2025-06-20 16:32:46.832', 10605, 1731, 48),
(6586, 'normally share stocks with Rubis zetech ', '2025-06-21 07:09:53.255', 10605, 1732, 62),
(6592, 'well stocked\nwell displayed\nvery slow movement...', '2025-06-21 07:40:12.358', 10605, 1733, 64),
(6596, 'Placed an order ', '2025-06-21 07:55:10.839', 10605, 1734, 30),
(6598, 'They are well stocked', '2025-06-21 07:58:18.527', 10605, 1735, 22),
(6600, 'nice display set up ', '2025-06-21 08:02:01.964', 10605, 1736, 70),
(6606, 'slow moving with a reason of selling high price even after I talked with them\n3000 puff ksh2300\n9000 puffs ksh3000', '2025-06-21 08:18:08.975', 10605, 1737, 62),
(6610, 'like our products ', '2025-06-21 08:28:39.767', 10605, 1738, 70),
(6612, 'well stocked ', '2025-06-21 08:29:32.957', 10605, 1739, 21),
(6614, 'They are well stocked', '2025-06-21 08:30:17.837', 10605, 1740, 22),
(6615, 'Talked to the owner and shared our catalog. Awaiting on possible order on follow up ', '2025-06-21 08:30:27.381', 10605, 1741, 35),
(6619, 'well stocked\nwell displayed...rrp @1570 and @2000', '2025-06-21 08:36:02.345', 10605, 1743, 64),
(6621, 'Follow up on this mini outlet for orders on pouches. To revisit again', '2025-06-21 08:38:30.876', 10605, 1744, 35),
(6625, 'They are waiting to be created ', '2025-06-21 08:43:01.849', 10605, 1745, 22),
(6633, 'Not ordering at the moment ', '2025-06-21 08:56:55.002', 10605, 1746, 30),
(6635, 'They\'re selling under the counter hence making the stocks to move slowly ', '2025-06-21 08:58:20.564', 10605, 1747, 21),
(6637, 'to place an order of 9000puff next week', '2025-06-21 08:59:10.834', 10605, 1748, 17),
(6638, 'The pouches are moving quickly  expecially the cooling mint.', '2025-06-21 08:59:19.467', 10605, 1749, 51),
(6649, 'placing their order next week ', '2025-06-21 09:39:12.197', 10605, 1750, 23),
(6651, 'making an order ', '2025-06-21 09:40:37.039', 10605, 1751, 49),
(6654, 'well displayed\nwell stocked...\nmovement:okey.', '2025-06-21 09:46:24.639', 10605, 1752, 64),
(6657, 'need an exchange of the 9000 puffs with 3000 puffs.', '2025-06-21 09:55:19.546', 10605, 1753, 23),
(6660, 'it\'s a new onboarding client \nplaced an order of 20pcs 3000puffs', '2025-06-21 10:00:20.223', 10605, 1754, 17),
(6661, 'made an order ', '2025-06-21 10:03:01.540', 10605, 1755, 49),
(6664, 'This client had promised to pay today but has not yet.', '2025-06-21 10:11:49.437', 10605, 1756, 23),
(6669, 'stock moving slowly in this outlet', '2025-06-21 10:27:38.951', 10605, 1757, 50),
(6673, 'just received their stock ', '2025-06-21 10:46:08.206', 10605, 1758, 49),
(6674, 'they were to place an order today I\'m here to push it now that the owner is in', '2025-06-21 10:46:10.546', 10605, 1759, 39),
(6680, 'trying to push for a restock of pouches though the owner is not interested ', '2025-06-21 10:57:09.609', 10605, 1760, 39),
(6681, 'not yet decided', '2025-06-21 10:57:37.070', 10605, 1761, 26),
(6686, 'collecting faulty ', '2025-06-21 12:01:40.061', 10605, 1762, 57),
(6687, 'Following up on payments ', '2025-06-21 12:05:22.569', 10605, 1763, 57),
(6688, 'they are awaiting their order but they still have 3 pieces left \nno pending payment\nfor the coming stock will be paid today or Monday ', '2025-06-21 12:11:18.424', 10605, 1764, 39),
(6691, 'No sales for the past 2 weeks.', '2025-06-21 12:15:01.141', 10605, 1765, 57),
(6695, '15pcs vapes to be delivered. own collection ', '2025-06-21 14:16:43.776', 10605, 1766, 47),
(6696, '10pcs vapes received today. ', '2025-06-21 14:46:13.356', 10605, 1767, 47),
(6700, '10pcs vapes received ', '2025-06-21 15:00:20.424', 10605, 1768, 47),
(6709, 'pushing for payment ', '2025-06-23 07:29:04.387', 10605, 1769, 48),
(6711, 'well stocked on the vapes and Pouches ', '2025-06-23 07:37:16.425', 10605, 1770, 32),
(6713, 'still', '2025-06-23 07:38:05.263', 10605, 1771, 48),
(6716, 'pushing for payment ', '2025-06-23 07:46:50.583', 10605, 1772, 48),
(6719, 'made an order ', '2025-06-23 07:53:20.882', 10605, 1773, 48),
(6723, 'Trying to Onboard them ', '2025-06-23 08:13:27.308', 10605, 1774, 32),
(6725, 'pushing for reorder of pouches ', '2025-06-23 08:13:58.852', 10605, 1775, 48),
(6728, '* the movement of the product is well ', '2025-06-23 08:15:59.180', 10605, 1776, 7),
(6735, 'uku kumenyqmaza', '2025-06-23 08:32:36.595', 10605, 1777, 48),
(6738, 'they have placed order for tomorrow ', '2025-06-23 09:15:45.536', 10605, 1778, 40),
(6741, 'well stocked on pouches... pushing for an order on the vapes', '2025-06-23 09:52:29.949', 10605, 1779, 32),
(6750, 'placed an order but the client still wants the yn available flavors. he couldn\'t be convinced ', '2025-06-23 10:46:26.813', 10605, 1780, 47),
(6756, 'New Outlet ', '2025-06-23 11:14:31.253', 10605, 1781, 40),
(6757, 'outlet well stocked with all SKUs ', '2025-06-23 11:15:17.047', 10605, 1782, 47),
(6762, 'well stocked\nwill do exchange of vapes wirh pouches due to slow movement', '2025-06-23 11:31:21.259', 10605, 1783, 64),
(6764, 'paying the pending invoice today ', '2025-06-23 11:31:58.274', 10605, 1784, 47),
(6765, 'well stocked\nwill exchañge vapes with GP due to slow movement', '2025-06-23 11:32:18.503', 10605, 1785, 64),
(6769, 'Well stocked on pouches and vapes. Store Manager will ensure balance is cleared by this week. ', '2025-06-23 11:38:48.335', 10605, 1786, 57),
(6774, 'H by ', '2025-06-23 11:44:54.519', 10605, 1787, 21),
(6775, 'They have enough stocks ', '2025-06-23 11:45:12.202', 10605, 1788, 21),
(6782, 'Still making follow up with them  after the after they asked me to check in today . ', '2025-06-23 12:05:47.061', 10605, 1789, 35),
(6784, 'Received their order. Following client complaint on receiving invoives without ETR.', '2025-06-23 12:15:25.169', 10605, 1790, 57),
(6789, 'slow sales on this outlet ', '2025-06-23 12:18:08.872', 10605, 1791, 35),
(6799, '*to place order by this week', '2025-06-23 12:35:31.869', 10605, 1792, 7),
(6800, 'Unable to meet the owner for the past 2 months with each visit to this client ending in futile payment. Following up on expected payment date. ', '2025-06-23 12:36:22.460', 10605, 1793, 57),
(6802, 'currently meeting with Isaac. he promised to give me an order by COB ', '2025-06-23 12:42:56.538', 10605, 1794, 47),
(6804, 'Booster is the competitor in this market.', '2025-06-23 12:43:44.835', 10605, 1795, 51),
(6808, 'New boarding, just received a order', '2025-06-23 12:53:38.366', 10605, 1796, 35),
(6812, 'New boarding made an order of 10 PCs of gold pouch for a start', '2025-06-23 13:05:25.664', 10605, 1797, 35),
(6819, 'Will not be placing orders until mid July. Client only wants to stock 300 puffs. Retailing at Ksh. 2000 extremely slow product movement. Biggest competitor is shisha', '2025-06-23 13:22:11.321', 10605, 1798, 57),
(6824, '5 pieces remaining. \nSlow movement ', '2025-06-23 13:42:14.247', 10605, 1799, 49),
(6827, 'Closed until re-opening on July 25th.', '2025-06-23 13:55:50.079', 10605, 1800, 57),
(6829, 'Waiting for an order placed on Saturday ', '2025-06-23 14:00:19.284', 10605, 1801, 49),
(6834, 'A new Onboarding, just received their order ', '2025-06-23 15:02:29.221', 10605, 1802, 49),
(6837, 'following up on an order, the owner asked for a meeting this evening ', '2025-06-23 15:20:43.168', 10605, 1803, 35),
(6841, 'well stocked.\nwell displayed.', '2025-06-24 06:51:17.497', 10605, 1804, 64),
(6844, 'well stocked \nwell displayed\nprices a bit higher...management insists they stay same.', '2025-06-24 07:00:18.133', 10605, 1805, 64),
(6849, 'Pouches are out of stock though they cannot order due to pending payment. \nThe competitor is elfbar  and solobar.', '2025-06-24 07:18:04.329', 10605, 1806, 51),
(6850, 'well stocked\nwell displayed\nvapes are slow moving but GP is moving fine\nrrp for vapes is @1700\nrrp for GP is @600', '2025-06-24 07:18:49.125', 10605, 1807, 64),
(6854, 'well displayed\nhere to collect payment...will reorder after.', '2025-06-24 07:34:33.154', 10605, 1808, 64),
(6860, 'they placed order last week Monday but arrived half of it\nwe have again placed another order ', '2025-06-24 07:52:18.625', 10605, 1809, 62),
(6864, 'Follow-up to see if I will get order ', '2025-06-24 07:58:11.704', 10605, 1810, 40),
(6865, 'Slow sales but picking up mdogo mdogo', '2025-06-24 07:58:40.211', 10605, 1811, 35),
(6867, 'The 9000puffs are fast moving. Competitor is hart.', '2025-06-24 08:01:43.763', 10605, 1812, 51),
(6869, 'Follow-up for order ', '2025-06-24 08:04:36.641', 10605, 1813, 40),
(6871, 'the outlet has slow sales since they are selling in a container. The outlet is doing their renovations ', '2025-06-24 08:08:56.383', 10605, 1814, 23),
(6874, 'placed an order ', '2025-06-24 08:17:39.343', 10605, 1815, 62),
(6875, 'we have a pending order to place, there\'s been some back office issues ', '2025-06-24 08:17:58.703', 10605, 1816, 35),
(6877, 'waiting for feedback from owner ', '2025-06-24 08:26:56.612', 10605, 1817, 40),
(6882, 'not yet received their order ', '2025-06-24 08:33:12.975', 10605, 1818, 63),
(6890, 'not yet received their order ', '2025-06-24 08:55:44.498', 10605, 1819, 63),
(6895, 'stock moving slowly', '2025-06-24 08:59:42.209', 10605, 1820, 50),
(6896, 'The products are well displayed .Sky is in the market. ', '2025-06-24 09:01:06.961', 10605, 1821, 51),
(6898, 'Still following up on boarding them', '2025-06-24 09:02:18.290', 10605, 1822, 35),
(6904, 'have sold one pouches wich is an improvement ', '2025-06-24 09:04:43.276', 10605, 1823, 48),
(6907, 'They are well stocked', '2025-06-24 09:05:08.247', 10605, 1824, 22),
(6918, 'still on follow up.. I couldn\'t find her but talked to the assistant ', '2025-06-24 09:14:29.240', 10605, 1825, 35),
(6920, 'well stocked ', '2025-06-24 09:16:07.867', 10605, 1826, 63),
(6921, 'still on follow up.. I couldn\'t find her but talked to the assistant ', '2025-06-24 09:16:49.114', 10605, 1827, 35),
(6928, 'will get an order this week before Friday ', '2025-06-24 09:24:33.036', 10605, 1828, 32),
(6929, 'Follow-up for order ', '2025-06-24 09:24:37.371', 10605, 1829, 40),
(6931, 'they like ', '2025-06-24 09:26:10.338', 10605, 1830, 70),
(6932, 'They like our products and about to give us order ', '2025-06-24 09:26:28.445', 10605, 1831, 102),
(6933, 'new outlet I have recruited\nwe have placed order 90pcs vapes and 50 PCs pouches\nI will share LPO tomorrow morning or tonight ', '2025-06-24 09:26:43.917', 10605, 1832, 62),
(6935, 'Vaoe codes still nit active', '2025-06-24 09:28:21.302', 10605, 1833, 30),
(6940, 'They are well stocked', '2025-06-24 09:34:36.831', 10605, 1834, 22),
(6941, 'following up for boarding ', '2025-06-24 09:36:39.574', 10605, 1835, 35),
(6942, 'The product is slow moving in the outlet ', '2025-06-24 09:36:46.571', 10605, 1836, 23),
(6945, 'The 3000puffs  are moving quickly.compared to the 9000puffs .', '2025-06-24 09:44:22.465', 10605, 1837, 51),
(6948, 'it\'s been slaw \nbut customers are satisfied by our product ', '2025-06-24 09:46:30.920', 10605, 1838, 48),
(6951, 'outlet stocked', '2025-06-24 09:49:16.887', 10605, 1839, 50),
(6952, 'no current stock, pushing for payment ', '2025-06-24 09:54:17.040', 10605, 1840, 49),
(6954, 'The new purchasing manager asked me to get feedback tomorrow.', '2025-06-24 09:57:08.929', 10605, 1841, 23),
(6958, 'moving slowly that\'s why they are not placing orders', '2025-06-24 09:59:38.964', 10605, 1842, 63),
(6967, 'well stocked ', '2025-06-24 10:13:10.570', 10605, 1843, 63),
(6972, 'kumetulia tu', '2025-06-24 10:21:17.286', 10605, 1844, 48),
(6978, 'They like our products and order 10pcs right away ', '2025-06-24 10:30:53.564', 10605, 1845, 102),
(6980, 'like and make oder', '2025-06-24 10:31:11.164', 10605, 1846, 70),
(6981, 'We are placing order', '2025-06-24 10:32:12.617', 10605, 1847, 22),
(6985, 'it\'s been slaw ', '2025-06-24 10:34:50.335', 10605, 1848, 48),
(6987, 'The outlet has few PCs for the vapes,they are yet to place an order with Titus', '2025-06-24 10:41:42.957', 10605, 1849, 23),
(6990, 'pouches delivered we haven’t sold even a single piece ', '2025-06-24 10:46:12.427', 10605, 1850, 20),
(6993, 'Trying to Onboard them ', '2025-06-24 10:49:42.721', 10605, 1851, 32),
(6996, 'have 20 pcs  of heart vape', '2025-06-24 10:52:58.960', 10605, 1852, 48),
(6999, 'outlet selling too slow', '2025-06-24 10:58:21.479', 10605, 1853, 50),
(7003, 'just received their stock ', '2025-06-24 11:03:25.344', 10605, 1854, 49),
(7008, 'fair movement ', '2025-06-24 11:08:53.662', 10605, 1855, 49),
(7011, 'gogo is the competitor in this market', '2025-06-24 11:14:16.628', 10605, 1856, 51),
(7013, 'well stocked on both pouches and vapes', '2025-06-24 11:18:54.181', 10605, 1857, 32),
(7021, 'They will place a new order the first week of next month.', '2025-06-24 11:34:29.387', 10605, 1858, 23),
(7025, 'They will make an order  when the higher  approves.', '2025-06-24 11:38:53.393', 10605, 1859, 51),
(7027, 'paid', '2025-06-24 11:42:52.263', 10605, 1860, 47),
(7033, 'to pay the pending invoices ', '2025-06-24 12:04:14.848', 10605, 1861, 47),
(7042, 'made an order', '2025-06-24 12:40:25.779', 10605, 1862, 49),
(7043, 'Still very well stocked. Products moving slowly at this location. BAC has put limitations on orders being placed from July onwards. ', '2025-06-24 12:41:43.707', 10605, 1863, 57),
(7044, 'Collected  cheque for previous order, and made another order ', '2025-06-24 12:47:52.419', 10605, 1864, 49),
(7047, 'waiting for the vapes to finish so as to place an order next week probably ', '2025-06-24 12:56:14.190', 10605, 1865, 32),
(7048, 'Following up on boarding them. it\'s a keg joint with a good sale can do better on pouches', '2025-06-24 12:57:42.805', 10605, 1866, 35),
(7051, 'The outlet is doing a handover to new management. I will get a new order once settled', '2025-06-24 13:07:25.478', 10605, 1867, 23),
(7052, 'Trying to Onboard them ', '2025-06-24 13:08:35.399', 10605, 1868, 32),
(7054, 'Received their order. ', '2025-06-24 13:10:47.929', 10605, 1869, 57),
(7059, 'to place order for 3000 puffs', '2025-06-24 13:22:10.415', 10605, 1870, 26),
(7061, 'Slow sales gave out some to elparaiso garden\'s for sale same owner. ', '2025-06-24 13:24:24.383', 10605, 1871, 35),
(7062, 'There is slow movement. ', '2025-06-24 13:24:35.830', 10605, 1872, 47),
(7065, 'Received their order of 40 pouches. ', '2025-06-24 13:37:39.989', 10605, 1873, 57),
(7068, 'well stocked', '2025-06-24 13:42:08.643', 10605, 1874, 26),
(7070, 'Spoke with accountant. Payment will take place 1st week of July', '2025-06-24 13:58:08.664', 10605, 1875, 57),
(7072, 'well stocked ', '2025-06-24 14:05:33.392', 10605, 1876, 46),
(7075, 'Not placing orders until current stocks finish. Products are moving slowly. ', '2025-06-24 14:19:36.482', 10605, 1877, 57),
(7078, 'They want vapes on consignment ', '2025-06-24 15:20:32.079', 10605, 1878, 32),
(7079, 'They are well stocked gogo is the competitor. ', '2025-06-24 15:23:04.051', 10605, 1879, 51),
(7082, 'just received their stock ', '2025-06-24 15:29:20.167', 10605, 1880, 49),
(7085, 'They have paid the pending invoice. ', '2025-06-24 15:47:45.320', 10605, 1881, 47),
(7088, 'Magunas makutano closed today due to demonstrations', '2025-06-25 07:27:35.676', 10605, 1882, 47),
(7089, 'Couldn\'t get the director ', '2025-06-25 07:41:42.856', 10605, 1883, 35),
(7090, 'closed down due to the demos', '2025-06-25 07:47:22.839', 10605, 1884, 35),
(7091, 'closed on demo\'s ', '2025-06-25 07:51:57.454', 10605, 1885, 35),
(7092, 'closed due to demo\'s ', '2025-06-25 07:54:14.273', 10605, 1886, 35),
(7097, 'shop about to close due toaandamano', '2025-06-25 08:56:27.319', 10605, 1887, 47),
(7100, 'well stocked ', '2025-06-25 10:03:49.632', 10605, 1888, 46),
(7104, 'Payment successfully processed.', '2025-06-25 10:17:11.471', 10605, 1889, 57),
(7107, 'Very well stocked on pouches and vapes. Owner is not in to process payment. Staff inquiring about B-C payment.', '2025-06-25 11:12:18.957', 10605, 1890, 57),
(7110, 'expecting order end week', '2025-06-25 11:22:37.806', 10605, 1891, 46),
(7111, 'well stocked ', '2025-06-25 11:23:32.755', 10605, 1892, 32),
(7115, 'well stocked stocked ', '2025-06-25 11:42:05.389', 10605, 1893, 46),
(7118, 'Very well stocked. Received their pouch order. ', '2025-06-25 12:02:15.303', 10605, 1894, 57),
(7119, 'well stocked ', '2025-06-25 12:02:16.649', 10605, 1895, 46),
(7123, 'Not planning to place order until 2nd or 3rd week of July', '2025-06-25 13:18:56.732', 10605, 1896, 57),
(7125, 'Visiting to encourage client to order. ', '2025-06-25 14:35:11.355', 10605, 1897, 57),
(7128, 'well stocked.\nwell displayed.\nrrp @2000 and @1570', '2025-06-26 07:59:03.557', 10605, 1898, 64),
(7135, 'product moving slowly. to return them to the office. ', '2025-06-26 08:21:35.521', 10605, 1899, 12),
(7139, 'well stocked with 3k puffs,9k Puffs and pouches ', '2025-06-26 08:23:56.338', 10605, 1900, 63),
(7144, 'well stocked\nwell displayed....\nmovement:slow but steady.\nmight reorder from next week.', '2025-06-26 08:30:48.565', 10605, 1901, 64),
(7151, 'They finally accepted to place an order on 1st July.', '2025-06-26 08:37:53.965', 10605, 1902, 23),
(7152, 'well displayed\nwell stocked.\nmoving okey...rrp @1570 and @2000', '2025-06-26 08:38:03.718', 10605, 1903, 64),
(7153, 'received 10pcs pine mint 3k puffs but I haven\'t been given a TO', '2025-06-26 08:38:14.304', 10605, 1904, 47),
(7155, 'Sales movement okay', '2025-06-26 08:39:51.829', 10605, 1905, 35),
(7156, 'we are placing another order since last order haven\'t arrived from last week ', '2025-06-26 08:40:33.745', 10605, 1906, 62),
(7160, 'not yet received their order ', '2025-06-26 08:53:56.638', 10605, 1907, 63),
(7165, 'no deliveries have been made so far, waiting for Tuesday order to be delivered ', '2025-06-26 09:09:48.541', 10605, 1908, 26),
(7167, 'The competitor is hart .', '2025-06-26 09:15:05.715', 10605, 1909, 51),
(7172, 'They well stocked', '2025-06-26 09:20:55.436', 10605, 1910, 22),
(7174, 'well stocked and well displated.', '2025-06-26 09:23:09.442', 10605, 1911, 64),
(7176, 'sales movement slow. ', '2025-06-26 09:24:40.356', 10605, 1912, 35),
(7178, 'received the order ', '2025-06-26 09:28:50.808', 10605, 1913, 48),
(7182, 'stock moving quite well', '2025-06-26 09:32:09.914', 10605, 1914, 50),
(7187, 'They will place an order next month', '2025-06-26 09:42:22.955', 10605, 1915, 23),
(7190, 'to do an exchange of flavours. ', '2025-06-26 09:44:59.225', 10605, 1916, 12),
(7193, 'pushing for 3k order ', '2025-06-26 09:46:29.278', 10605, 1917, 48),
(7195, 'they need a sample of 5dots\n', '2025-06-26 09:49:20.507', 10605, 1918, 63),
(7196, 'they\'re requesting a sample of 5dots ', '2025-06-26 09:50:00.377', 10605, 1919, 63),
(7200, 'the movement is okay ', '2025-06-26 09:58:45.868', 10605, 1920, 39),
(7204, 'asked them them to update the previous order on 5 dot\'s tomorrow . stocks on Vapes okay. ', '2025-06-26 10:07:14.641', 10605, 1921, 35),
(7207, 'in stock ', '2025-06-26 10:11:42.986', 10605, 1922, 48),
(7209, 'Doing follow up on boarding, manager shared contact details for main office in nrb', '2025-06-26 10:13:31.244', 10605, 1923, 35),
(7216, 'well stocked ', '2025-06-26 10:20:28.526', 10605, 1924, 7),
(7220, 'moving slowly ', '2025-06-26 10:24:36.510', 10605, 1925, 63),
(7221, 'we have placed new order since the last one got expired before they had received their first time woosh products ', '2025-06-26 10:27:49.652', 10605, 1926, 62),
(7223, 'Received their previous order today. ', '2025-06-26 10:29:36.434', 10605, 1927, 35),
(7224, 'delivered their stock today', '2025-06-26 10:33:47.230', 10605, 1928, 17),
(7230, 'waiting for an order today \nwas ', '2025-06-26 10:39:25.404', 10605, 1929, 39),
(7235, 'The movements is okay', '2025-06-26 10:51:27.607', 10605, 1930, 22),
(7245, 'slow moving due to overpricing yet they neighbour quickmart and naivas which sell at fair prices attracting customers', '2025-06-26 11:02:22.166', 10605, 1931, 62),
(7253, 'The products movement is slow.', '2025-06-26 11:11:01.906', 10605, 1932, 51),
(7254, 'Trying to Onboard them ', '2025-06-26 11:14:16.285', 10605, 1933, 32),
(7259, 'Store manager is not in to process pending payment. ', '2025-06-26 11:25:33.423', 10605, 1934, 57),
(7262, 'Slow movement but they are moving.sky is the competitor. ', '2025-06-26 11:27:20.965', 10605, 1935, 51),
(7267, 'Order received. 9k puffs 10pcs . \npreparing payments. ', '2025-06-26 11:40:23.200', 10605, 1936, 47),
(7269, 'They are yet to receive the 9000 puffs vapes', '2025-06-26 11:42:22.321', 10605, 1937, 23),
(7270, 'order received 9k puffs 10pcs. preparing payments. ', '2025-06-26 11:43:51.451', 10605, 1938, 47),
(7275, 'the movement is slow\npushing for payment ', '2025-06-26 11:48:29.968', 10605, 1939, 39),
(7278, 'we have been placing orders always and non this month has ever received.on Saturday we will place another order ', '2025-06-26 11:54:31.198', 10605, 1940, 62),
(7283, 'Sky is moving faster compared to the three dot ', '2025-06-26 12:04:04.449', 10605, 1941, 51),
(7285, 'there is a faulty vape', '2025-06-26 12:06:35.944', 10605, 1942, 47),
(7292, 'the outlet is well stocked , to place order today', '2025-06-27 06:35:45.538', 10605, 1943, 26),
(7301, 'The pouches are moving faster\nand currently there are no competitors. ', '2025-06-27 07:56:26.059', 10605, 1944, 51),
(7306, 'Cooling mint is moving quickly especially 5dot.', '2025-06-27 08:09:48.132', 10605, 1945, 51),
(7308, '9k puffs moving very slow. \n', '2025-06-27 08:10:58.508', 10605, 1946, 47),
(7317, 'well stocked in 3k puffs and GP\n9K Puffs not in stock due to slow movement\nVapes moving slow\nGP moving okey', '2025-06-27 08:20:05.035', 10605, 1947, 64),
(7318, 'The ly have requested I share a price list and pictures for our product. Then we can have a conversation from there.', '2025-06-27 08:23:59.484', 10605, 1948, 23),
(7321, 'well stocked ', '2025-06-27 08:30:40.230', 10605, 1949, 21),
(7322, 'we have a faulty ill pick it up', '2025-06-27 08:31:07.800', 10605, 1950, 31),
(7325, 'will place orders next month,\nmoving slowly ', '2025-06-27 08:37:24.793', 10605, 1951, 62),
(7328, 'Trying to onboard\nFeedback: They will order.Will contact me within next week', '2025-06-27 08:38:54.718', 10605, 1952, 64),
(7331, 'low sale turn out in general on the shop. ', '2025-06-27 08:42:24.310', 10605, 1953, 35),
(7335, 'The products are moving slowly. ', '2025-06-27 08:46:18.167', 10605, 1954, 51),
(7339, 'There\'s slow movement of vapes. ', '2025-06-27 08:54:02.137', 10605, 1955, 47),
(7343, 'we have placed orders 3 time not received any of them', '2025-06-27 08:55:39.192', 10605, 1956, 31),
(7345, 'received their order\nwill order again next month\ncompetitors are x booster and sky', '2025-06-27 08:56:08.768', 10605, 1957, 62),
(7351, 'Received their order yesterday ', '2025-06-27 09:03:55.288', 10605, 1958, 35),
(7352, 'They are well stocked', '2025-06-27 09:04:04.307', 10605, 1959, 22),
(7363, 'quick orc is closed indefinitely ', '2025-06-27 09:16:43.695', 10605, 1960, 31),
(7365, 'it\'s slaw but kuna watu wanauliza ', '2025-06-27 09:18:04.323', 10605, 1961, 48),
(7366, 'pouches moving just well. ', '2025-06-27 09:18:24.081', 10605, 1962, 47),
(7369, 'They ordered 10pcs of 3000puffs', '2025-06-27 09:19:50.428', 10605, 1963, 32),
(7370, 'Total Rhino closed until further notice ', '2025-06-27 09:22:29.476', 10605, 1964, 31),
(7374, 'The new management, Dealer is settling in and will start placing orders from next month.', '2025-06-27 09:25:01.445', 10605, 1965, 23),
(7375, 'well stocked\nwell displayed.', '2025-06-27 09:25:04.046', 10605, 1966, 64),
(7377, 'Received their order. ', '2025-06-27 09:25:23.269', 10605, 1967, 35),
(7380, 'They are out of stocks', '2025-06-27 09:31:15.615', 10605, 1968, 22),
(7381, 'The vapes are slow moving they have placed an order on pouches.', '2025-06-27 09:35:38.147', 10605, 1969, 51),
(7384, 'Products movement is quit slow', '2025-06-27 09:42:50.458', 10605, 1970, 30),
(7387, 'pouches moving well. \npl1', '2025-06-27 09:47:00.082', 10605, 1971, 47),
(7390, 'pouches moving well. client is preparing the pending payment. ', '2025-06-27 09:47:37.060', 10605, 1972, 47),
(7395, 'well stocked in 3k and 9k puffs\n\nwell displayed\n\nTold to wait for rennovations to conclude to mount display', '2025-06-27 09:53:46.436', 10605, 1973, 64),
(7408, 'no sale yet\nbut has no challenge \nonly law foot flaw', '2025-06-27 10:08:58.053', 10605, 1974, 48),
(7422, 'Slow movement ', '2025-06-27 10:17:58.299', 10605, 1975, 49),
(7426, 'They are well stocked', '2025-06-27 10:21:16.208', 10605, 1976, 22),
(7427, 'we need to do activation ', '2025-06-27 10:25:05.945', 10605, 1977, 44),
(7428, 'strictly pushing for payment ', '2025-06-27 10:25:32.625', 10605, 1978, 39),
(7430, 'We talked with the owner to make payments.', '2025-06-27 10:29:18.595', 10605, 1979, 23),
(7434, 'delivery done ', '2025-06-27 10:32:34.735', 10605, 1980, 20),
(7438, 'Very well stocked. ', '2025-06-27 10:34:31.103', 10605, 1981, 57),
(7445, 'they have placed an order today', '2025-06-27 10:44:37.548', 10605, 1982, 50),
(7446, 'pouches are more moving than vapes ', '2025-06-27 10:46:08.568', 10605, 1983, 62),
(7449, 'the movement is very slow on all skus ', '2025-06-27 10:49:51.474', 10605, 1984, 26),
(7458, 'no sale yet', '2025-06-27 11:01:19.947', 10605, 1985, 48),
(7466, 'no sale yet\nthere has been police checks so there has been slaw flaw of customers ', '2025-06-27 11:16:12.145', 10605, 1986, 48),
(7469, 'requesting an exchange From pouches to vapes', '2025-06-27 11:22:51.721', 10605, 1987, 49),
(7476, 'They received their order yesterday ', '2025-06-27 11:25:52.567', 10605, 1988, 23),
(7479, 'they have placed an order of 15 PCs vapes', '2025-06-27 11:27:06.981', 10605, 1989, 7),
(7480, 'waiting for a pending delivery ', '2025-06-27 11:27:15.110', 10605, 1990, 20),
(7483, 'law football flow', '2025-06-27 11:28:22.107', 10605, 1991, 48),
(7493, 'Product is still moving slowly, next expected order date 2nd to 3rd week of July. ', '2025-06-27 11:35:59.150', 10605, 1992, 57),
(7494, 'They\'re well stocked ', '2025-06-27 11:36:30.292', 10605, 1993, 21),
(7499, 'good movement ', '2025-06-27 11:52:16.829', 10605, 1994, 49),
(7501, 'client client had an issue but sorted it out ', '2025-06-27 11:53:45.846', 10605, 1995, 35),
(7504, 'are moving slowly ', '2025-06-27 11:55:41.702', 10605, 1996, 62),
(7507, 'To reorder next week', '2025-06-27 11:57:24.812', 10605, 1997, 35),
(7509, 'to meet up the owner at 6 in the evening for an order. ', '2025-06-27 12:01:30.389', 10605, 1998, 35),
(7513, 'Movement is relatively slow', '2025-06-27 12:10:53.066', 10605, 1999, 32),
(7517, 'Following up on payments. Owner has travelled again. Pushing accountants to facilitate payment. Currently they have only sold 4pcs since they were last stocked on 30th April. ', '2025-06-27 12:14:51.292', 10605, 2000, 57),
(7518, 'The product is picking in sales.', '2025-06-27 12:39:38.677', 10605, 2001, 23),
(7519, 'trying to sort their exchange ', '2025-06-27 12:41:57.047', 10605, 2002, 39),
(7525, 'Their price is too high. Not convinced to reduce their price ', '2025-06-27 12:44:21.688', 10605, 2003, 49),
(7526, 'no sales for 2 months. ', '2025-06-27 12:44:36.342', 10605, 2004, 57),
(7528, 'normally place orders once per month since this month we ordered they have confirmed to do another order next month ', '2025-06-27 12:47:18.221', 10605, 2005, 62),
(7536, 'order to be placed from1st', '2025-06-27 13:28:01.301', 10605, 2006, 20),
(7537, 'slow moving ', '2025-06-27 13:43:53.256', 10605, 2007, 20),
(7542, 'Collecting faulty. ', '2025-06-28 07:45:13.616', 10605, 2008, 57),
(7549, 'still stocked\nwell displayed.', '2025-06-28 08:00:26.950', 10605, 2009, 64),
(7551, 'Trying to Onboard them ', '2025-06-28 08:14:16.969', 10605, 2010, 32),
(7555, 'display will be taken next week since the manager will be around that time ', '2025-06-28 08:26:00.204', 10605, 2011, 62),
(7563, 'For the past one week and some days the stock is moving slowly ', '2025-06-28 08:41:33.904', 10605, 2012, 21),
(7564, 'Placing orders for vapes on Monday ', '2025-06-28 08:42:17.746', 10605, 2013, 20),
(7567, 'following up on boarding especially for pouches ', '2025-06-28 08:48:11.633', 10605, 2014, 35),
(7570, 'well stocked\nwell displayed...', '2025-06-28 08:50:09.040', 10605, 2015, 64),
(7571, 'The products are well displayed. The competitor is sky and hart', '2025-06-28 08:51:47.534', 10605, 2016, 51),
(7575, 'Follow up on boarding the outlet. she had promised to do so this week', '2025-06-28 08:55:10.692', 10605, 2017, 35),
(7579, 'went for an order, couldn\'t reach her on the shop but made a call check back', '2025-06-28 09:02:19.893', 10605, 2018, 35),
(7580, 'Still selling under the counter ', '2025-06-28 09:02:25.073', 10605, 2019, 21),
(7582, 'Follow-up to an board with them ', '2025-06-28 09:06:48.622', 10605, 2020, 40),
(7589, 'they are out of stock on all pouches was pushing for a restock ', '2025-06-28 11:25:58.143', 10605, 2021, 39),
(7590, 'the outlet has no power since Monday and can\'t place an order ', '2025-06-28 11:26:00.303', 10605, 2022, 23),
(7592, 'still pushing for feedback since the owner was complaining about our multiple flavors ', '2025-06-28 11:30:09.050', 10605, 2023, 39),
(7594, 'to place order next week. \n', '2025-06-28 12:04:39.162', 10605, 2024, 21),
(7600, 'well stocked', '2025-06-28 14:32:11.331', 10605, 2025, 26),
(7602, 'no 3000puffs delivery has been done', '2025-06-28 14:43:52.752', 10605, 2026, 26),
(7605, 'well stocked in 3k and 9k puffs\nwell displayed...will need woosh display', '2025-06-30 07:28:54.312', 10605, 2027, 64),
(7606, 'still has enough stock ', '2025-06-30 07:46:11.999', 10605, 2028, 12),
(7611, 'no sales so far', '2025-06-30 10:30:20.024', 10605, 2029, 109),
(7614, 'Cooling mint is moving well', '2025-06-30 10:41:27.823', 10605, 2030, 48),
(7619, 'it\'s been slaw ', '2025-06-30 10:47:09.915', 10605, 2031, 48),
(7621, 'very slow movement, vapes are overpriced ', '2025-06-30 10:52:07.764', 10605, 2032, 49),
(7624, 'kumetulia', '2025-06-30 10:54:17.242', 10605, 2033, 48),
(7628, 'no sale\nno challenge ', '2025-06-30 11:00:40.086', 10605, 2034, 48),
(7630, 'Movement is slow but okay, sales ladies creating awareness. ', '2025-06-30 11:05:11.589', 10605, 2035, 35),
(7633, 'no sales recorded so far in 3 weeks', '2025-06-30 11:18:08.768', 10605, 2036, 35),
(7638, 'pushing for payment ', '2025-06-30 11:20:05.321', 10605, 2037, 48),
(7641, 'Following up on an order and on boarding ', '2025-06-30 11:23:10.020', 10605, 2038, 35),
(7642, '5 Dot pouch moving well. Can not make an order for sold out vape flavours until current stocks significantly reduce. ', '2025-06-30 11:26:15.242', 10605, 2039, 57),
(7645, 'Pending order awaiting approval ', '2025-06-30 11:33:28.648', 10605, 2040, 35),
(7649, 'Following up on progress of payments. Accountant agreed to work on it this week. Products have not been selling at this outlet due to low season. ', '2025-06-30 11:40:03.645', 10605, 2041, 57),
(7653, 'Still no sales after 2 months of stocking the products. ', '2025-06-30 11:50:07.015', 10605, 2042, 57),
(7657, 'Having a meeting with the manager for , however he\'s claiming they\'ll do so in peak season not now', '2025-06-30 11:54:21.887', 10605, 2043, 35),
(7661, 'to collect cheque tomorrow ', '2025-06-30 12:01:41.151', 10605, 2044, 49),
(7663, 'Owner doesn\'t want to place an order until mid July. ', '2025-06-30 12:08:38.240', 10605, 2045, 57),
(7673, 'stock selling slowly', '2025-06-30 12:24:28.420', 10605, 2046, 50),
(7675, 'I have convinced them to display the products again ', '2025-06-30 12:39:23.497', 10605, 2047, 39),
(7681, 'checked in for payment ', '2025-06-30 13:01:32.179', 10605, 2048, 35),
(7695, 'slow moving but still moving.', '2025-06-30 13:25:21.721', 10605, 2049, 104),
(7696, 'pushing for the re order ', '2025-06-30 13:26:09.279', 10605, 2050, 39),
(7699, 'To place an order 2nd week of July. ', '2025-06-30 13:27:24.313', 10605, 2051, 57),
(7702, 'following up for the pending payment ', '2025-06-30 13:32:47.468', 10605, 2052, 47),
(7706, 'pouches available no vapes', '2025-06-30 13:40:31.535', 10605, 2053, 104),
(7708, '*product moving slow \n* competitetor hart', '2025-06-30 13:41:25.653', 10605, 2054, 7),
(7709, 'returning 31pcs 3dots to exchange with 3000puffs.', '2025-06-30 13:47:03.585', 10605, 2055, 47),
(7711, 'trying to onboard them ', '2025-06-30 13:58:26.730', 10605, 2056, 39),
(7714, 'well stocked', '2025-06-30 14:05:22.466', 10605, 2057, 46),
(7716, 'order placed l, own collection but not yet delivered', '2025-06-30 14:47:35.529', 10605, 2058, 47),
(7718, 'order placed ', '2025-06-30 17:24:57.897', 10605, 2059, 20),
(7720, 'well stocked', '2025-07-01 06:36:04.615', 10605, 2060, 32),
(7734, '*new client trying to onboard them ', '2025-07-01 07:44:29.608', 10605, 2061, 7),
(7737, 'they have not sold a single piece ', '2025-07-01 07:49:35.036', 10605, 2062, 12),
(7742, 'slow moving', '2025-07-01 08:07:00.442', 10605, 2063, 104),
(7749, 'well stocked ', '2025-07-01 08:16:09.052', 10605, 2064, 63),
(7752, '*new outlet in my route trying to onboard them ', '2025-07-01 08:20:28.372', 10605, 2065, 7),
(7756, 'They cannot make a reorder due to pending payments. ', '2025-07-01 08:27:44.778', 10605, 2066, 51),
(7757, 'They currently dont have gold pouches ', '2025-07-01 08:28:32.611', 10605, 2067, 51),
(7760, 'No sales so far ', '2025-07-01 08:35:32.601', 10605, 2068, 109),
(7763, 'they will place order for 3000puffs', '2025-07-01 08:38:31.549', 10605, 2069, 63),
(7767, 'have made an order of 10 pouches ', '2025-07-01 08:45:02.660', 10605, 2070, 35),
(7775, 'well displayed\nlow stock...will place order', '2025-07-01 08:49:34.889', 10605, 2071, 64),
(7779, 'They well stocked7', '2025-07-01 08:56:14.950', 10605, 2072, 22),
(7782, 'They are expecting to complete renovations in August.', '2025-07-01 09:00:52.524', 10605, 2073, 23),
(7783, 'They are expecting to complete renovations in August.', '2025-07-01 09:00:59.701', 10605, 2074, 23),
(7789, 'The products are moving slowly  for now expecially the pouches', '2025-07-01 09:09:58.571', 10605, 2075, 51),
(7791, 'display to be hing', '2025-07-01 09:12:29.006', 10605, 2076, 48),
(7794, 'Making follow up on boarding ', '2025-07-01 09:13:53.265', 10605, 2077, 35),
(7806, 'moving slowly ', '2025-07-01 09:26:59.362', 10605, 2078, 63),
(7811, 'well stocked', '2025-07-01 09:30:05.950', 10605, 2079, 22),
(7813, 'They are working on making payments then place another order.', '2025-07-01 09:31:01.071', 10605, 2080, 23),
(7814, 'We\'ve updated the previous order after the price change\'s ', '2025-07-01 09:31:36.345', 10605, 2081, 35),
(7818, 'They have dept with Dantra so they are in a position to place order', '2025-07-01 09:36:17.661', 10605, 2082, 22),
(7820, 'The three dot are moving slowly. They will place an order for the five dot.', '2025-07-01 09:41:14.473', 10605, 2083, 51),
(7823, 'management had said they would call...following up on that\n\nThey are not available today.will revisit.', '2025-07-01 09:42:40.342', 10605, 2084, 64);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(7826, 'are placing another order this start of the month ', '2025-07-01 09:43:12.619', 10605, 2085, 62),
(7831, 'They\'re well stocked ', '2025-07-01 09:51:18.489', 10605, 2086, 21),
(7835, 'Asked me to come back tomorrow for the order as I meet the owner', '2025-07-01 09:53:08.971', 10605, 2087, 23),
(7837, 'placing an order this week', '2025-07-01 09:53:52.215', 10605, 2088, 63),
(7841, 'Very well stocked 44 pouches, 28 3000 puffs, 1 9000 puffs. Store Manager is not yet back from leave to facilitate payments. ', '2025-07-01 09:57:08.248', 10605, 2089, 57),
(7845, 'well stocked\nwell displayed', '2025-07-01 09:59:54.007', 10605, 2090, 64),
(7847, 'the are not go to restock at this moment ', '2025-07-01 10:03:22.942', 10605, 2091, 40),
(7850, 'The products are well displayed they are slow moving expecially 9000puffs ', '2025-07-01 10:13:08.094', 10605, 2092, 51),
(7853, 'doing well on pouches', '2025-07-01 10:17:03.964', 10605, 2093, 50),
(7857, 'moving slowly ', '2025-07-01 10:18:40.501', 10605, 2094, 63),
(7865, 'outlet doing well', '2025-07-01 10:27:03.909', 10605, 2095, 50),
(7866, 'Good movement \nExpecting am order soon ', '2025-07-01 10:29:02.100', 10605, 2096, 49),
(7870, 'To make an order next week ', '2025-07-01 10:31:48.986', 10605, 2097, 35),
(7872, 'placing their order today ', '2025-07-01 10:34:21.819', 10605, 2098, 57),
(7875, 'well stocked in 3k puffs and GP\nWell displayed.', '2025-07-01 10:36:35.471', 10605, 2099, 64),
(7883, 'Fair Movement \nExpecting an order soon', '2025-07-01 10:41:40.756', 10605, 2100, 49),
(7891, 'Following up with the outlet for boarding ', '2025-07-01 10:48:14.648', 10605, 2101, 35),
(7899, 'display is urgently required \nproducts are still not moving well', '2025-07-01 11:01:07.254', 10605, 2102, 109),
(7905, 'They have ongoing renovations', '2025-07-01 11:14:58.230', 10605, 2103, 49),
(7911, 'Pushing for payment ', '2025-07-01 11:18:23.145', 10605, 2104, 49),
(7916, 'Still well stocked on all flavours. ', '2025-07-01 11:25:41.211', 10605, 2105, 57),
(7930, 'have enough stocks ', '2025-07-01 11:44:53.551', 10605, 2106, 62),
(7931, 'Finally placed an order but for the Goldpouches. They refused vapes because they transferred they order to another branch ', '2025-07-01 11:46:31.846', 10605, 2107, 23),
(7937, 'Following up with this out together with Magnum for boarding \n', '2025-07-01 11:48:14.078', 10605, 2108, 35),
(7945, '*promised to order from distributor ', '2025-07-01 11:53:15.104', 10605, 2109, 7),
(7947, 'New Onboarding \nMaking an order ', '2025-07-01 11:54:56.930', 10605, 2110, 49),
(7948, '43 pouches and 73 vapes ', '2025-07-01 11:56:55.457', 10605, 2111, 62),
(7953, 'still placing orders with Titus. following up on this so that I can be allowed intp the outlet.', '2025-07-01 12:09:23.745', 10605, 2112, 23),
(7962, 'order is coming this week ', '2025-07-01 12:18:37.598', 10605, 2113, 20),
(7965, 'was sorting on the issue on the delivery and collection of cheque ', '2025-07-01 12:21:16.321', 10605, 2114, 39),
(7967, 'I will redo this visitation since it\'s past 3pm\n', '2025-07-01 12:24:03.897', 10605, 2115, 23),
(7969, 'well stocked ', '2025-07-01 12:25:36.097', 10605, 2116, 21),
(7972, 'Order for vapes will be placed at the end of the month. ', '2025-07-01 12:36:55.646', 10605, 2117, 57),
(7976, 'no complains the movement is okay ', '2025-07-01 12:53:27.292', 10605, 2118, 39),
(7981, '*out of stock thus reordered 5 PCs from baseline ', '2025-07-01 13:18:35.174', 10605, 2119, 7),
(7983, 'also encouraged them to display their products again ', '2025-07-01 13:25:38.988', 10605, 2120, 39),
(7985, 'the movement of the pouches is very slow ', '2025-07-01 13:28:36.372', 10605, 2121, 39),
(7991, 'products are moving but slow', '2025-07-01 13:30:55.905', 10605, 2122, 109),
(7993, 'pushing for payment so that we restock for them', '2025-07-01 13:34:06.518', 10605, 2123, 39),
(7995, 'received the order \n', '2025-07-01 13:42:34.790', 10605, 2124, 48),
(8009, 'to order vapes after payment ', '2025-07-01 14:30:00.769', 10605, 2125, 47),
(8010, '*to order from distributor ', '2025-07-01 14:32:28.603', 10605, 2126, 7),
(8013, 'have enough stocks ', '2025-07-01 14:40:40.771', 10605, 2127, 62),
(8016, '*placed an order of 60 PCs from their HQ ', '2025-07-01 14:54:58.654', 10605, 2128, 7),
(8022, 'still looking for customers of the products although are being threatened by county government ', '2025-07-01 15:13:53.299', 10605, 2129, 62),
(8026, 'well stocked ', '2025-07-01 17:54:04.706', 10605, 2130, 40),
(8027, 'still following up for onboarding ', '2025-07-01 19:33:50.073', 10605, 2131, 20),
(8032, 'They\'re well stocked ', '2025-07-02 06:55:58.434', 10605, 2132, 21),
(8039, 'well stocked\nwell displayed...\nrrp @1570 and @2000', '2025-07-02 07:25:58.122', 10605, 2133, 64),
(8041, 'asked whether they can ways of creating product awareness to the like bringing empty display to show their is our products around,,,\nhart been our competitors here they brought empty display ', '2025-07-02 07:29:26.721', 10605, 2134, 62),
(8043, 'They\'re well stocked but we\'ve placed order for the sold out items ', '2025-07-02 07:32:26.380', 10605, 2135, 21),
(8044, 'The pouches are moving quickly. Hart is currently in the market at 1200.', '2025-07-02 07:40:41.749', 10605, 2136, 51),
(8047, '*to place order for 5 dots once done selling 3 dots', '2025-07-02 07:47:12.941', 10605, 2137, 7),
(8050, 'naivas orders are much delaying to reach market.\n', '2025-07-02 07:55:53.656', 10605, 2138, 62),
(8054, 'well stocked ', '2025-07-02 07:57:52.715', 10605, 2139, 63),
(8056, 'well stocked\nwell displayed....\nrrp @1570 and @2000 \nno competition.', '2025-07-02 07:59:15.279', 10605, 2140, 64),
(8059, 'The pouches are moving quickly. ', '2025-07-02 08:08:56.769', 10605, 2141, 51),
(8063, 'pushing for a restock ', '2025-07-02 08:19:15.069', 10605, 2142, 39),
(8067, 'they have not received their order for pouches', '2025-07-02 08:24:05.583', 10605, 2143, 63),
(8073, 'products are moving but slow', '2025-07-02 08:30:41.630', 10605, 2144, 109),
(8074, 'well Stocked ', '2025-07-02 08:31:30.276', 10605, 2145, 21),
(8084, 'Display mounting needed ', '2025-07-02 08:44:22.577', 10605, 2146, 30),
(8085, 'we need to send a push girl to push for the stocks', '2025-07-02 08:44:35.238', 10605, 2147, 39),
(8088, 'Closed down for renovations. ', '2025-07-02 08:53:57.296', 10605, 2148, 35),
(8089, 'The vapes are moving slowly. ', '2025-07-02 08:56:37.446', 10605, 2149, 51),
(8094, 'Very few guests purchase Woosh, biggest competitor is Shisha being sold at 1500. 3000 puffs RRP: Ksh.2000 ', '2025-07-02 09:09:10.126', 10605, 2150, 57),
(8103, 'good moving ', '2025-07-02 09:14:49.364', 10605, 2151, 63),
(8104, 'order for vapes recivied', '2025-07-02 09:14:54.863', 10605, 2152, 20),
(8110, 'they were affected by demonstrations that happened last week', '2025-07-02 09:22:06.297', 10605, 2153, 31),
(8114, 'The movement is very low', '2025-07-02 09:26:31.974', 10605, 2154, 22),
(8115, 'They will give an order before the week ends.', '2025-07-02 09:27:33.186', 10605, 2155, 23),
(8116, 'They will give an order before the week ends.', '2025-07-02 09:27:58.927', 10605, 2156, 23),
(8119, 'moving slowly but picking up ', '2025-07-02 09:30:05.606', 10605, 2157, 63),
(8128, 'They are well stoxked', '2025-07-02 09:41:52.973', 10605, 2158, 22),
(8130, 'pushing for a reorder ', '2025-07-02 09:43:43.097', 10605, 2159, 39),
(8133, 'Vape sales have severely declined during low season. ', '2025-07-02 09:47:37.034', 10605, 2160, 57),
(8142, 'Gogo is the competitor  in this market.', '2025-07-02 09:53:24.694', 10605, 2161, 51),
(8146, 'to. pol', '2025-07-02 10:00:09.906', 10605, 2162, 21),
(8147, 'to place order next week ', '2025-07-02 10:00:26.905', 10605, 2163, 21),
(8158, 'they would want an exchange of pouches will facilitate it next week ', '2025-07-02 10:10:39.992', 10605, 2164, 39),
(8169, 'They are well stocked', '2025-07-02 10:16:46.448', 10605, 2165, 22),
(8174, 'Following up on payment progress. ', '2025-07-02 10:21:18.119', 10605, 2166, 57),
(8178, 'pushing for an order for vapes', '2025-07-02 10:24:02.167', 10605, 2167, 39),
(8179, 'the display fell from where we had mounted it. I used mounting tape,I think it needs silicon to be firm on the wall. ', '2025-07-02 10:24:26.577', 10605, 2168, 47),
(8183, 'I was unable to count on the vapes since they were so occupied with stock taking ', '2025-07-02 10:34:16.407', 10605, 2169, 39),
(8187, 'They are well stocked', '2025-07-02 10:42:34.204', 10605, 2170, 22),
(8193, '1pc Australian mango faulty ', '2025-07-02 10:47:28.661', 10605, 2171, 30),
(8202, '9000puffs moving fast, to place order of the sold out products. Though the moving falvors here are out of stock ', '2025-07-02 11:05:18.143', 10605, 2172, 21),
(8205, 'have collected their cheque too', '2025-07-02 11:09:10.979', 10605, 2173, 39),
(8207, 'will place an order this month but haven\'t specified the day ', '2025-07-02 11:10:50.612', 10605, 2174, 62),
(8211, 'we are placing order this week', '2025-07-02 11:14:17.263', 10605, 2175, 22),
(8213, '*waiting for the product from warehouse ', '2025-07-02 11:18:39.536', 10605, 2176, 7),
(8218, 'to pick cheque tomorrow. ', '2025-07-02 11:27:22.930', 10605, 2177, 12),
(8220, 'still stocked up', '2025-07-02 11:30:45.447', 10605, 2178, 35),
(8226, 'will place orders on Friday by now are only receiving orders ', '2025-07-02 11:41:34.957', 10605, 2179, 62),
(8227, 'follow-up on the pending payment. ', '2025-07-02 11:41:45.926', 10605, 2180, 47),
(8229, 'following up on the pending payment. to pay on Saturday. ', '2025-07-02 11:44:02.392', 10605, 2181, 47),
(8241, 'have a pending order of 50 pcs', '2025-07-02 12:18:21.983', 10605, 2182, 35),
(8245, 'following up on boarding ', '2025-07-02 12:28:36.742', 10605, 2183, 35),
(8247, 'They want to exchange the 9000 puffs with Goldpouches since they have overstayed with no sales', '2025-07-02 12:33:45.747', 10605, 2184, 23),
(8251, 'Checked in for an order. ', '2025-07-02 12:41:09.504', 10605, 2185, 35),
(8254, 'They will place their order on Friday ', '2025-07-02 12:42:18.309', 10605, 2186, 23),
(8255, 'This outlet is notorious with overprcing', '2025-07-02 12:45:34.903', 10605, 2187, 23),
(8256, '3000 puffs rrp @ksh 2400', '2025-07-02 12:45:59.342', 10605, 2188, 23),
(8258, 'vapes 16pcs pouches 21pcs', '2025-07-02 12:46:44.835', 10605, 2189, 20),
(8262, 'Pushing for owner to make an order this month', '2025-07-02 13:40:37.017', 10605, 2190, 57),
(8263, 'well stocked ', '2025-07-02 13:41:05.083', 10605, 2191, 32),
(8265, 'Have ordered 10pcs of 3000puffs', '2025-07-02 13:56:34.135', 10605, 2192, 32),
(8267, 'Trying to Onboard them ', '2025-07-02 14:02:26.655', 10605, 2193, 32),
(8269, 'Trying to Onboard them ', '2025-07-02 14:06:33.977', 10605, 2194, 32),
(8278, 'to place order in Saturday ', '2025-07-02 14:46:48.237', 10605, 2195, 47),
(8284, 'pending order to be delivered tomorrow ', '2025-07-02 15:20:01.789', 10605, 2196, 26),
(8285, 'Trying to Onboard them ', '2025-07-02 15:29:54.186', 10605, 2197, 32),
(8287, 'still has a pending payment. ', '2025-07-03 06:05:51.199', 10605, 2198, 12),
(8291, 'They don\'t want to stock our vapes... claiming that customers are complaining how fast the vapes are finishing.', '2025-07-03 07:16:30.035', 10605, 2199, 32),
(8293, 'well stocked in vapes both 3k and 9k puffs\nGP might reorder next week...theyve asked i wait they move.', '2025-07-03 07:17:53.499', 10605, 2200, 64),
(8295, 'we will place orders once we reduce to 10 pcs', '2025-07-03 07:22:05.158', 10605, 2201, 62),
(8303, 'good moving ', '2025-07-03 07:51:19.815', 10605, 2202, 63),
(8304, 'well displayed\nwell stocked\nmovement:okey.', '2025-07-03 07:51:27.248', 10605, 2203, 64),
(8305, 'good moving for pouches 5dots', '2025-07-03 07:52:09.811', 10605, 2204, 63),
(8308, 'well stocked...order was received.\nwell displayed', '2025-07-03 08:09:00.824', 10605, 2205, 64),
(8311, 'no sales in the last three weeks, few customer walk-ins', '2025-07-03 08:15:23.223', 10605, 2206, 35),
(8317, 'display needed at carrefour garden city ', '2025-07-03 08:24:31.634', 10605, 2207, 63),
(8318, 'No sales yet since delivery ', '2025-07-03 08:25:56.168', 10605, 2208, 35),
(8326, 'Sales are moderate, requesting status on stock return for the fast moving 9000 puffs. ', '2025-07-03 08:37:22.747', 10605, 2209, 57),
(8327, 'selling by piece not outer, opened one for sales. ', '2025-07-03 08:37:52.529', 10605, 2210, 35),
(8329, 'vapes \n9000 puffs 5 pcs\n3000puffs -6 pcs \n3 dots 24pcs\n5dots 23pcs', '2025-07-03 08:38:43.908', 10605, 2211, 109),
(8337, 'The five dot cooling mint are moving faster\nsky is the competitor ', '2025-07-03 08:44:06.252', 10605, 2212, 51),
(8342, 'To place an order once 9000 puffs fast moving flavours return. ', '2025-07-03 08:48:26.042', 10605, 2213, 57),
(8346, 'waiting for the stock placed last week ', '2025-07-03 08:57:04.509', 10605, 2214, 62),
(8348, '*well stocked ', '2025-07-03 08:59:11.098', 10605, 2215, 7),
(8353, 'Very well stocked.', '2025-07-03 09:01:53.136', 10605, 2216, 57),
(8357, 'Very well stocked. ', '2025-07-03 09:07:11.684', 10605, 2217, 57),
(8359, 'Moving slowly ', '2025-07-03 09:08:24.336', 10605, 2218, 63),
(8363, 'payment received ', '2025-07-03 09:14:08.446', 10605, 2219, 57),
(8364, '*they have 7 PCs remaining ', '2025-07-03 09:14:35.195', 10605, 2220, 7),
(8369, 'They placed an order for the flavors depleted', '2025-07-03 09:17:24.319', 10605, 2221, 23),
(8373, 'received their stocks ', '2025-07-03 09:19:17.587', 10605, 2222, 57),
(8380, 'The movement is slowly  especially the 3dot pouches', '2025-07-03 09:26:54.342', 10605, 2223, 51),
(8384, 'They\'ll reorder again', '2025-07-03 09:32:09.269', 10605, 2224, 22),
(8388, 'follow up fora reorder ', '2025-07-03 09:34:47.613', 10605, 2225, 35),
(8391, 'Sales in the outlet are picking. they sold 5 PCs last month ', '2025-07-03 09:39:43.306', 10605, 2226, 23),
(8395, 'well stocked but still selling under the counter ', '2025-07-03 09:43:48.935', 10605, 2227, 21),
(8396, 'products are moving so well', '2025-07-03 09:47:25.698', 10605, 2228, 109),
(8398, 'They don\'t have our products', '2025-07-03 09:48:18.241', 10605, 2229, 22),
(8402, 'following up for boarding especially on pouches ', '2025-07-03 09:56:06.823', 10605, 2230, 35),
(8403, 'The owner is interest they are yet to onboard', '2025-07-03 09:56:07.480', 10605, 2231, 22),
(8410, 'received the 8vapes+3kpuffs)that were for exchange. ', '2025-07-03 10:13:19.197', 10605, 2232, 47),
(8413, 'they received their order ', '2025-07-03 10:22:53.652', 10605, 2233, 63),
(8416, '*moving slow\n*competitetor gogo,sky', '2025-07-03 10:26:33.771', 10605, 2234, 7),
(8417, 'The competitor is gogo', '2025-07-03 10:27:10.794', 10605, 2235, 51),
(8419, 'The vapes have no competitors  currently. ', '2025-07-03 10:47:28.942', 10605, 2236, 51),
(8423, 'They are well stocked', '2025-07-03 10:49:26.496', 10605, 2237, 22),
(8425, 'The outlet will place an order for the vapes next week.', '2025-07-03 10:56:22.652', 10605, 2238, 23),
(8427, 'to place order for vapes next week after payment ', '2025-07-03 10:59:36.119', 10605, 2239, 47),
(8433, 'The owner has not stocked on pouches due to the previous  returns.', '2025-07-03 11:09:57.509', 10605, 2240, 51),
(8448, 'The owner has not paid yet, Susan is helping to sort this issue out with Totalenergies office.', '2025-07-03 11:39:40.361', 10605, 2241, 23),
(8450, 'placed an order today. 30pcs vapes. ', '2025-07-03 11:44:15.707', 10605, 2242, 47),
(8451, 'placed an order for 30pcs vapes. ', '2025-07-03 11:45:42.974', 10605, 2243, 47),
(8459, 'the 9000 puffs does better than the 3000 puffs', '2025-07-03 11:58:46.545', 10605, 2244, 114),
(8460, 'have opened today after the break since gen z had stolen products and destroyed the shop \nafter they settle they will place orders ', '2025-07-03 11:59:08.991', 10605, 2245, 62),
(8463, 'the pouches did poorly in Havana liquor and cocktail bar \nthe client looks forward to on board vapes', '2025-07-03 12:07:29.684', 10605, 2246, 114),
(8469, 'the client on boarded other pouches named SWAG', '2025-07-03 12:18:36.336', 10605, 2247, 114),
(8473, 'They will place another order with Joshua', '2025-07-03 12:33:06.342', 10605, 2248, 23),
(8475, 'potential client was trying to onboard them ', '2025-07-03 12:37:27.671', 10605, 2249, 39),
(8480, 'potential client trying to onboard them ', '2025-07-03 12:44:56.765', 10605, 2250, 39),
(8482, 'in the process of looking new customers ', '2025-07-03 12:47:58.479', 10605, 2251, 62),
(8483, 'potential client trying to onboard them ', '2025-07-03 12:49:38.294', 10605, 2252, 39),
(8485, 'client is requesting for a sample. ', '2025-07-03 12:50:45.727', 10605, 2253, 47),
(8487, 'the vapes move but slowly\nthe client requests for a display to identify if the remaining products will move faster ', '2025-07-03 12:52:21.254', 10605, 2254, 114),
(8498, 'improve on the pouches strength', '2025-07-03 13:41:13.348', 10605, 2255, 114),
(8507, 'selling at lower rate ', '2025-07-03 14:00:10.752', 10605, 2256, 62),
(8524, 'following up on boarding especially pouches ', '2025-07-03 15:07:34.963', 10605, 2257, 35),
(8525, 'following up in with a possible order they promised ', '2025-07-03 15:39:56.943', 10605, 2258, 35),
(8526, 'follow up on boarding ', '2025-07-03 15:40:50.799', 10605, 2259, 35),
(8538, 'well stocked in vapes\nslow movement due to location\nno competition\nrrp @1570 and @2000', '2025-07-04 06:48:43.709', 10605, 2260, 64),
(8546, 'well stocked\nwell displayed...\nmovement:okey\nno competition.', '2025-07-04 07:10:14.884', 10605, 2261, 64),
(8556, 'They are well stocked', '2025-07-04 07:32:45.104', 10605, 2262, 22),
(8560, 'stocked in 3000 puffs and all flavours GP\nRRP @500 and @1570\nno competition', '2025-07-04 07:43:47.308', 10605, 2263, 64),
(8563, 'following up on boarding stocking of pouches ', '2025-07-04 07:54:14.299', 10605, 2264, 35),
(8568, 'well stocked\nwell displayed\ncompetition:none\nprices @1570 and @2000', '2025-07-04 07:59:35.411', 10605, 2265, 64),
(8573, 'well stocked ', '2025-07-04 08:18:44.833', 10605, 2266, 63),
(8581, 'have a case of debt with dantra on this flavors they have ', '2025-07-04 08:24:40.169', 10605, 2267, 62),
(8583, 'They have a dept with dantra', '2025-07-04 08:24:53.531', 10605, 2268, 22),
(8584, 'well Stocked but we\'ve placed order for pouches ', '2025-07-04 08:25:03.014', 10605, 2269, 21),
(8586, 'following up and on boarding as she was interested in the pouches ', '2025-07-04 08:30:31.623', 10605, 2270, 35),
(8591, 'The 3000puffs are moving quickly.The competitor is gogo', '2025-07-04 08:46:23.374', 10605, 2271, 51),
(8597, 'placed order yesterday ', '2025-07-04 09:01:25.545', 10605, 2272, 62),
(8598, 'they have not received their order for gold pouch 5dots', '2025-07-04 09:01:27.247', 10605, 2273, 63),
(8605, 'let\'s work on communicating effectively about the pricing of our vapes', '2025-07-04 09:24:31.240', 10605, 2274, 114),
(8615, 'the client is supplied by hart', '2025-07-04 09:37:41.298', 10605, 2275, 114),
(8617, 'They are well stocked', '2025-07-04 09:38:09.155', 10605, 2276, 22),
(8618, 'moving slowly but picking up ', '2025-07-04 09:38:36.643', 10605, 2277, 63),
(8621, 'The pouches are moving quickly ', '2025-07-04 09:44:14.229', 10605, 2278, 51),
(8626, 'sold all sweetmint  pouches ', '2025-07-04 09:52:18.038', 10605, 2279, 48),
(8635, 'moving slowly ', '2025-07-04 10:00:01.022', 10605, 2280, 63),
(8636, 'The competitor is hart.', '2025-07-04 10:00:54.401', 10605, 2281, 51),
(8637, '5pcs 2500puffs still not returned to their hq ', '2025-07-04 10:00:54.556', 10605, 2282, 30),
(8646, 'they still have the ,45 pieces that were supplied to them \ntheir issue is overpricing ', '2025-07-04 10:07:24.098', 10605, 2283, 39),
(8647, '9000 puffs is preferable in microhub liquor store ', '2025-07-04 10:07:32.921', 10605, 2284, 114),
(8648, 'received their stock, well stocked on all sku', '2025-07-04 10:07:44.147', 10605, 2285, 35),
(8661, 'products movement it\'s still stagnant ', '2025-07-04 10:16:43.271', 10605, 2286, 109),
(8664, 'The movement  is slow ', '2025-07-04 10:18:37.379', 10605, 2287, 51),
(8669, '*trying to onboard them ', '2025-07-04 10:20:46.611', 10605, 2288, 7),
(8670, 'moving good', '2025-07-04 10:20:55.515', 10605, 2289, 63),
(8672, 'Zero sales so far', '2025-07-04 10:23:40.453', 10605, 2290, 35),
(8675, 'they used to stock they stopped working on reo boarding them again ', '2025-07-04 10:28:08.589', 10605, 2291, 39),
(8677, 'They are well stocked', '2025-07-04 10:29:38.260', 10605, 2292, 22),
(8682, 'the display together with the vapes were taken from the outlet', '2025-07-04 10:32:38.298', 10605, 2293, 114),
(8684, 'There was a change of management, waiting on a pending order they were to give', '2025-07-04 10:34:57.327', 10605, 2294, 35),
(8687, 'Not ordering due to county issues of no display of nicotine products ', '2025-07-04 10:38:13.454', 10605, 2295, 30),
(8690, 'order will be placed tomorrow ', '2025-07-04 10:41:23.664', 10605, 2296, 62),
(8700, 'have displayed ', '2025-07-04 10:52:50.605', 10605, 2297, 48),
(8701, '3000puffs are moving well. hoping to place an order by next week. ', '2025-07-04 10:53:39.605', 10605, 2298, 47),
(8708, 'The pouches are very slow', '2025-07-04 11:04:10.275', 10605, 2299, 51),
(8709, 'they are using our display for other brands complaining about space to put other displays\nToris help to speak with them ', '2025-07-04 11:04:26.111', 10605, 2300, 39),
(8711, '*to place order from baseline ', '2025-07-04 11:06:26.473', 10605, 2301, 7),
(8715, 'Called in for some clarification on faulty which wasn\'t the case. ', '2025-07-04 11:10:05.014', 10605, 2302, 35),
(8716, 'vapes are still stagnant but pouches are moving ', '2025-07-04 11:11:08.861', 10605, 2303, 109),
(8721, '9k puffs moving very slow. ', '2025-07-04 11:26:03.238', 10605, 2304, 47),
(8724, 'the vapes are not available ', '2025-07-04 11:30:57.921', 10605, 2305, 114),
(8725, 'Hart is currently in the market and dominating the market', '2025-07-04 11:33:18.885', 10605, 2306, 51),
(8728, 'to do a top up soon ', '2025-07-04 11:35:39.103', 10605, 2307, 12),
(8732, 'kuko slaw', '2025-07-04 11:38:58.707', 10605, 2308, 48),
(8733, 'display mounted in the outlet ', '2025-07-04 11:45:40.438', 10605, 2309, 23),
(8737, 'well stocked \n', '2025-07-04 11:52:59.939', 10605, 2310, 21),
(8740, 'stock moving but slow', '2025-07-04 11:54:40.687', 10605, 2311, 35),
(8742, '9000 puffs 3pcs\n3000pufss 8pcs', '2025-07-04 12:00:52.834', 10605, 2312, 109),
(8745, 'we will place order on Monday. gold pouches ', '2025-07-04 12:02:30.618', 10605, 2313, 47),
(8747, 'have stocked  hart vapes and pouches \nvape at 1200\npouches at 800', '2025-07-04 12:03:59.353', 10605, 2314, 48),
(8749, 'vapes \n9000puffs 3pcs\n3000puffs 8pcs', '2025-07-04 12:05:40.482', 10605, 2315, 109),
(8751, 'not yet received the order and will not pay before getting the order', '2025-07-04 12:06:49.300', 10605, 2316, 104),
(8758, 'They are stock out but not yet paid. to pay tomorrow ', '2025-07-04 12:21:55.935', 10605, 2317, 47),
(8759, 'moving 👍', '2025-07-04 12:24:51.147', 10605, 2318, 104),
(8762, 'stock still moving slowly', '2025-07-04 12:29:04.417', 10605, 2319, 57),
(8765, 'To place an order next week ', '2025-07-04 12:31:57.127', 10605, 2320, 49),
(8769, 'Very slow movement. \nWill make an order soon', '2025-07-04 12:36:07.712', 10605, 2321, 49),
(8771, 'Replacing faulties', '2025-07-04 12:36:50.232', 10605, 2322, 57),
(8772, 'slow movement \nto place an order soon ', '2025-07-04 12:38:22.739', 10605, 2323, 49),
(8776, 'slow movement ', '2025-07-04 12:41:27.506', 10605, 2324, 57),
(8779, 'client returned a pouch no rush found while using ', '2025-07-04 12:43:09.673', 10605, 2325, 104),
(8782, 'waiting for the commission from b2c', '2025-07-04 12:44:08.486', 10605, 2326, 48),
(8783, 'no vape sales ', '2025-07-04 12:44:34.285', 10605, 2327, 57),
(8787, 'Pushing for payment \nFair movement ', '2025-07-04 12:52:51.184', 10605, 2328, 49),
(8789, 'client returned a pouch need to be taken back to the hq', '2025-07-04 12:55:11.805', 10605, 2329, 104),
(8790, 'movement 2 per week... already on board with the b2c', '2025-07-04 13:09:18.771', 10605, 2330, 104),
(8795, 'Making an order next week ', '2025-07-04 13:13:00.635', 10605, 2331, 49),
(8796, 'Making an order on gold pouches next week ', '2025-07-04 13:13:47.276', 10605, 2332, 49),
(8804, 'Good movement of pouches \nTo place another order soon ', '2025-07-04 13:31:02.439', 10605, 2333, 49),
(8809, 'corrected 9000 puffs codes and placed an order ', '2025-07-04 13:33:24.618', 10605, 2334, 62),
(8812, 'Extremely slow movement ', '2025-07-04 13:35:53.983', 10605, 2335, 49),
(8815, 'not ready to stock until end nonth', '2025-07-04 13:45:46.939', 10605, 2336, 57),
(8817, 'following up for onboarding ', '2025-07-04 14:01:34.135', 10605, 2337, 20),
(8818, '*reordered 15 PCs from distributor ', '2025-07-04 14:07:49.510', 10605, 2338, 7),
(8820, 'to order tomorrow or next week ', '2025-07-04 14:14:25.059', 10605, 2339, 47),
(8822, '*competitetor gogo and beast', '2025-07-04 14:17:27.803', 10605, 2340, 7),
(8827, 'still to place the order', '2025-07-04 14:34:53.119', 10605, 2341, 74),
(8832, 'anytime next week they will give an order ', '2025-07-04 14:42:46.379', 10605, 2342, 62),
(8834, 'we need a display for our products', '2025-07-04 14:58:27.410', 10605, 2343, 20),
(8835, 'order to be placed by next week', '2025-07-04 15:04:05.867', 10605, 2344, 20),
(8836, 'order to be done early next week ', '2025-07-04 15:05:04.676', 10605, 2345, 20),
(8837, 'the supervisor had askede to come today evening for payment. waiting for him. ', '2025-07-04 15:06:14.255', 10605, 2346, 47),
(8840, 'the outlet was broken by goons they need our help in replacing the broken vapes', '2025-07-04 15:51:13.369', 10605, 2347, 20),
(8856, 'well stocked\nwell displayed\nrrp @2100 for 9k puffs and 550 for GP', '2025-07-05 07:44:39.334', 10605, 2348, 64),
(8865, 'They are well stocked', '2025-07-05 07:53:33.406', 10605, 2349, 22),
(8868, 'have enough stocks for now ', '2025-07-05 08:07:07.197', 10605, 2350, 62),
(8869, 'doing renovations ', '2025-07-05 08:15:08.851', 10605, 2351, 44),
(8873, 'well stocked\nwell displayed\ncompetition:Gogo', '2025-07-05 08:31:44.093', 10605, 2352, 64),
(8876, 'not well stocked ', '2025-07-05 08:33:47.536', 10605, 2353, 26),
(8879, 'stock still intact no movement as of last one month ', '2025-07-05 08:36:16.686', 10605, 2354, 35),
(8881, 'follow up on payment, was till closed. called the owner over the same', '2025-07-05 08:38:15.278', 10605, 2355, 35),
(8882, 'still having stocks', '2025-07-05 08:39:34.284', 10605, 2356, 20),
(8891, 'Good moving ', '2025-07-05 08:53:21.136', 10605, 2357, 63),
(8893, 'slow moving still pushing for an order from Maureen ', '2025-07-05 08:58:47.462', 10605, 2358, 104),
(8895, 'They are well stocked', '2025-07-05 08:59:52.922', 10605, 2359, 22),
(8899, 'following up on boarding and listing of our products ', '2025-07-05 09:05:36.135', 10605, 2360, 35),
(8903, 'they are complaining about order they have not received their order ', '2025-07-05 09:09:16.562', 10605, 2361, 63),
(8905, '9000puffs -3pcs\n3000puffs- 7pcs', '2025-07-05 09:11:35.284', 10605, 2362, 109),
(8910, 'very slow product movement. ', '2025-07-05 09:29:13.875', 10605, 2363, 57),
(8913, 'vapes \n9000puffs 3pcs\n3000puffs 7pcs', '2025-07-05 09:39:21.138', 10605, 2364, 109),
(8917, 'good moving ', '2025-07-05 09:50:55.924', 10605, 2365, 63),
(8920, 'well stocked in vapes\nGP were delivered this week\nrrp @1570,@2000 and @550\nno competition', '2025-07-05 09:53:33.249', 10605, 2366, 64),
(8925, 'Awaiting order to be approved ', '2025-07-05 10:02:33.443', 10605, 2367, 30),
(8926, 'They have not been sorted out on the sealed products by MOH.', '2025-07-05 10:10:14.128', 10605, 2368, 23),
(8928, 'Order placement end of month due to slow movement.', '2025-07-05 10:15:18.077', 10605, 2369, 57),
(8929, 'Their issue for the sealed products by MOH has not been solved ', '2025-07-05 10:15:41.224', 10605, 2370, 23),
(8936, 'The competitor is goat selling at 800 for the gold pouches. \nhart is also in the market.', '2025-07-05 10:26:00.739', 10605, 2371, 51),
(8944, 'Well stocked', '2025-07-05 10:30:25.586', 10605, 2372, 57),
(8953, 'They received an order of pouches', '2025-07-05 10:47:51.707', 10605, 2373, 51),
(8960, 'no shop.', '2025-07-05 10:55:29.470', 10605, 2374, 23),
(8971, 'trying to onboard them ', '2025-07-05 12:28:20.527', 10605, 2375, 39),
(8972, 'trying to onboard them \npotential client ', '2025-07-05 12:31:40.803', 10605, 2376, 39),
(8973, 'picking the order for Susan ', '2025-07-05 12:47:23.352', 10605, 2377, 39),
(8989, 'test', '2025-07-07 01:57:13.193', 10605, 2382, 94),
(8997, 'zero sales ', '2025-07-07 06:39:07.008', 10605, 2383, 109),
(8999, 'products are moving but in a very slow pace', '2025-07-07 07:06:36.322', 10605, 2384, 109),
(9000, 'sobieski liquor store closed due to the ongoing protests ', '2025-07-07 07:15:52.977', 10605, 2385, 47),
(9003, 'progressing well both pouches and vapes', '2025-07-07 07:34:34.708', 10605, 2386, 109),
(9006, 'to order 3k puffs next week', '2025-07-07 07:41:39.494', 10605, 2387, 47),
(9007, 'magunas makutano branch closed. ', '2025-07-07 07:42:58.681', 10605, 2388, 47),
(9008, 'came to collect the cheque. ', '2025-07-07 07:51:54.580', 10605, 2389, 47),
(9009, 'to pay then place an order later Today \n', '2025-07-07 07:55:58.583', 10605, 2390, 47),
(9014, 'progressing so well ', '2025-07-07 08:45:46.214', 10605, 2391, 109),
(9017, 'Requesting exchange of the 9000 puff flavours for fast moving flavour that are currently stocked out. ', '2025-07-07 10:12:27.572', 10605, 2392, 57),
(9020, 'Awaiting B2C payment. They have never received any incentive payment. ', '2025-07-07 10:40:34.078', 10605, 2393, 57),
(9026, 'gh', '2025-07-07 13:59:09.261', 10605, 2394, 94),
(9028, 'Still experiencing low sales period. Have not received B2C payment ', '2025-07-07 11:09:10.729', 10605, 2395, 57),
(9032, 'closed due to demo\'s ', '2025-07-07 11:26:49.172', 10605, 2396, 35),
(9035, 'To place order once 9000 puffs are restocked. ', '2025-07-07 12:03:41.235', 10605, 2397, 57),
(9038, 'Low season, slow sales. ', '2025-07-07 13:07:44.422', 10605, 2398, 57),
(9041, 'Movement is slow', '2025-07-07 13:27:50.230', 10605, 2399, 30),
(9045, 'Still following up on boarding ', '2025-07-07 15:11:56.210', 10605, 2400, 35),
(9053, 'they can\'t  order vapes due to lack of fan favourites flavours', '2025-07-08 06:27:41.009', 10605, 2401, 31),
(9058, 'Well stocked. Not affected by demonstrations ', '2025-07-08 06:44:22.049', 10605, 2402, 91),
(9076, 'making an order by Thursday', '2025-07-08 10:50:25.538', 10605, 2403, 46),
(9081, 'products are stagnant', '2025-07-08 10:53:02.675', 10605, 2404, 109),
(9089, 'well stocked and displayed\nvapes moving slow\nGP moving okey.\nno comperition.', '2025-07-08 08:16:17.609', 10605, 2405, 64),
(9093, 'well stocked\nwell displayed\nmovement:okey\ncompetition:none', '2025-07-08 08:27:32.379', 10605, 2406, 64),
(9098, 'well stocked ', '2025-07-08 08:35:43.541', 10605, 2407, 20),
(9104, 'well stocked', '2025-07-08 11:38:15.095', 10605, 2408, 46),
(9109, 'well stocked\nwell displayed\nmovement:slow', '2025-07-08 08:41:30.095', 10605, 2409, 64),
(9111, 'following up for the payment of the previous invoice. ', '2025-07-08 08:45:56.433', 10605, 2410, 47),
(9114, 'Stock movement is very slow... ', '2025-07-08 08:47:40.887', 10605, 2411, 30),
(9115, 'placed order', '2025-07-08 08:47:41.508', 10605, 2412, 57),
(9122, 'zinasonga but kuko slaw', '2025-07-08 08:50:50.440', 10605, 2413, 48),
(9127, 'placing orders towards the end of the week ', '2025-07-08 08:59:37.886', 10605, 2414, 62),
(9131, 'pushing for pouches order', '2025-07-08 09:07:04.963', 10605, 2415, 48),
(9147, 'well stocked\nwell displayed', '2025-07-08 09:32:04.937', 10605, 2416, 64),
(9152, 'waiting to receive the order', '2025-07-08 09:34:02.601', 10605, 2417, 48),
(9153, 'there is improvement in customers flaw', '2025-07-08 09:35:28.640', 10605, 2418, 48),
(9159, 'codes for 3000puffs and 9000puffs are inactive ', '2025-07-08 09:40:38.623', 10605, 2419, 21),
(9161, 'just made an order', '2025-07-08 12:41:19.050', 10605, 2420, 46),
(9162, 'lady assigned to make order was not in', '2025-07-08 09:41:32.748', 10605, 2421, 48),
(9166, 'Sales are picking up. Sold 1 vape in June. ', '2025-07-08 09:42:36.129', 10605, 2422, 57),
(9173, 'follow up on payment, managed to sell one pouch so far', '2025-07-08 12:46:19.824', 10605, 2425, 35),
(9177, 'They are requesting the non moving products to be returned to the office', '2025-07-08 12:47:16.026', 10605, 2426, 23),
(9191, 'to place an order in the course of the week', '2025-07-08 09:56:39.649', 10605, 2428, 49),
(9192, 'Stocks needed', '2025-07-08 09:56:48.608', 10605, 2429, 91),
(9194, 'we have placed order today ', '2025-07-08 09:57:46.006', 10605, 2430, 62),
(9200, 'no sales for almost two months', '2025-07-08 13:10:17.051', 10605, 2431, 35),
(9201, 'They are doing their renovations and have not placed a reorder with Titus Finance', '2025-07-08 13:11:30.804', 10605, 2432, 23),
(9202, 'stock well received waiting for payment ', '2025-07-08 10:19:49.097', 10605, 2433, 104),
(9204, 'well stocked ', '2025-07-08 10:23:24.381', 10605, 2434, 21),
(9207, 'payment by the end of the day hopefully ', '2025-07-08 10:26:37.790', 10605, 2435, 104),
(9213, 'follow up on boarding', '2025-07-08 13:33:06.745', 10605, 2436, 35),
(9225, 'in for a meeting ', '2025-07-08 10:48:59.023', 10605, 2437, 39),
(9234, 'well stocked', '2025-07-08 14:10:25.307', 10605, 2438, 46),
(9236, 'we placed order last week Friday,\nanother order will be placed after payment for this order is done for pouches ', '2025-07-08 11:12:14.161', 10605, 2439, 62),
(9241, 'well stocked but we placed order for Minty Snow 3000puffs 10pcs', '2025-07-08 11:15:19.889', 10605, 2440, 21),
(9245, 'have enough for their stock ', '2025-07-08 11:53:14.692', 10605, 2441, 62),
(9249, 'not moving at all,\nprices are KSH 550 and neighborhood quickmart kiambu road sells at 550 again \nissue of not displaying and more people preferring supermarket than Petro Mart it seems to be ', '2025-07-08 12:05:03.673', 10605, 2442, 62),
(9250, 'Trying to Onboard them ', '2025-07-08 12:10:55.013', 10605, 2443, 32),
(9252, 'very well stocked ', '2025-07-08 12:13:24.803', 10605, 2444, 57),
(9255, 'Balozi wines are requesting for a clear communication on the incentives part\n9000 puffs does better than 3000p', '2025-07-08 15:21:35.038', 10605, 2445, 114),
(9267, 'They are well stocked', '2025-07-08 15:29:19.336', 10605, 2447, 22),
(9271, 'well stocked', '2025-07-08 15:34:53.262', 10605, 2448, 46),
(9273, 'pushing for payment ', '2025-07-08 12:38:47.475', 10605, 2449, 39),
(9283, 'was here to push for an order but the liquor store was robbed yesterday \nthe client needs time ', '2025-07-08 12:55:12.251', 10605, 2450, 39),
(9285, 'well stocked needs a display', '2025-07-08 15:57:29.539', 10605, 2451, 46),
(9291, 'pushing for a restock ', '2025-07-08 13:10:29.800', 10605, 2453, 39),
(9295, 'To collect cheques in the course of the week ', '2025-07-08 13:16:11.580', 10605, 2454, 49),
(9296, 'they need the vapes back with a push girl', '2025-07-08 16:20:07.622', 10605, 2455, 114),
(9299, 'still well stocked on vapes and pouches', '2025-07-08 13:22:08.648', 10605, 2456, 20),
(9304, 'Returned 4 pieces of wild Luci ', '2025-07-08 13:50:34.104', 10605, 2457, 49),
(9305, 'waiting to stock', '2025-07-08 16:59:31.555', 10605, 2458, 109),
(9311, 'following up on the pending invoices for payment ', '2025-07-08 14:23:57.529', 10605, 2459, 47),
(9313, 'milimani, makutano. some shops as till closed. crafty casks liquor store is one of them.\n', '2025-07-08 14:27:37.320', 10605, 2460, 47),
(9317, 'not yet decided ', '2025-07-08 15:44:14.573', 10605, 2461, 20),
(9322, 'well stocked slowly moving follow-up this week', '2025-07-09 09:30:03.152', 10605, 2462, 40),
(9325, 'Well stocked ', '2025-07-09 06:51:26.756', 10605, 2463, 21),
(9328, 'received 10pcs Australian ice mango 3k puffs ', '2025-07-09 07:38:41.776', 10605, 2464, 47),
(9332, 'There a good flow so far on sale\'s. sold already 5 pieces', '2025-07-09 10:44:23.390', 10605, 2467, 35),
(9369, 'Good movement ', '2025-07-09 09:27:50.717', 10605, 2469, 49),
(9372, 'stock is still stagnant', '2025-07-09 12:29:55.556', 10605, 2470, 109),
(9376, 'Extremely slow movement ', '2025-07-09 09:35:52.845', 10605, 2471, 49),
(9378, 'Well stocked. Products are still moving slowly. ', '2025-07-09 09:37:07.984', 10605, 2472, 57),
(9379, 'waiting for payment', '2025-07-09 12:40:36.542', 10605, 2473, 104),
(9381, 'Replaced Gold Pouch with Velo 3 dot', '2025-07-09 09:43:12.413', 10605, 2474, 49),
(9384, '27 pouches awaiting payment', '2025-07-09 12:53:14.958', 10605, 2475, 104),
(9389, 'Very well stocked. Pending payments to be cleared before end of month. Staff still inquiring about B2C payments. ', '2025-07-09 10:01:02.937', 10605, 2478, 57),
(9393, 'will make an order on Friday', '2025-07-09 10:12:11.536', 10605, 2479, 48),
(9398, 'pushing for vape order', '2025-07-09 10:19:46.109', 10605, 2480, 48),
(9399, 'closed', '2025-07-09 10:24:44.864', 10605, 2481, 48),
(9402, 'well stocked and displayed\ncompetition:none', '2025-07-09 10:26:37.611', 10605, 2482, 64),
(9408, 'No sales at this location affecting overdue payments. ', '2025-07-09 10:28:45.489', 10605, 2483, 57),
(9414, 'slow moving', '2025-07-09 13:35:39.557', 10605, 2484, 46),
(9413, 'Improvement is noted', '2025-07-09 10:35:39.549', 10605, 2485, 49),
(9417, 'will make order next week', '2025-07-09 10:40:24.669', 10605, 2486, 48),
(9419, 'Have not sold any vapes in 2 months. ', '2025-07-09 10:42:55.072', 10605, 2487, 57),
(9422, 'well stocked\nGood display\ncompetition:Gogo\nMovement:okey.', '2025-07-09 10:45:02.929', 10605, 2488, 64),
(9425, 'pushing for payments', '2025-07-09 10:48:44.430', 10605, 2489, 48),
(9427, 'law foot flaw \npushing for payments', '2025-07-09 10:58:29.414', 10605, 2490, 48),
(9430, 'moving slowly but still pushing', '2025-07-09 14:05:37.051', 10605, 2491, 104),
(9431, 'moving slowly but still pushing', '2025-07-09 14:06:43.312', 10605, 2492, 104),
(9434, 'well stocked\nwell displayed\ncompetition:none\nmovement:okey', '2025-07-09 11:10:33.264', 10605, 2493, 64),
(9438, 'well stocked\nwell displayed\ncompetition:none\nmovement:slow', '2025-07-09 11:15:28.748', 10605, 2494, 64),
(9445, 'trying to onboard them ', '2025-07-09 11:26:46.262', 10605, 2495, 39),
(9448, 'well stocked', '2025-07-09 14:39:28.132', 10605, 2496, 46),
(9453, 'expecting their payment this week ', '2025-07-09 12:04:22.175', 10605, 2497, 39),
(9457, 'slow moving', '2025-07-09 15:05:31.796', 10605, 2498, 46),
(9460, 'Still have 9pcs remaining. ', '2025-07-09 12:21:10.464', 10605, 2499, 57),
(9463, 'Good movement. ', '2025-07-09 12:29:32.213', 10605, 2500, 49),
(9464, 'Stock out', '2025-07-09 15:30:56.255', 10605, 2501, 46),
(9467, 'well stocked', '2025-07-09 15:59:00.444', 10605, 2502, 46),
(9471, 'they have complains on not being paid for b to c incentives ', '2025-07-09 13:10:51.724', 10605, 2504, 39),
(9472, 'well stocked', '2025-07-09 16:11:50.348', 10605, 2505, 46),
(9476, 'pushing for a restock ', '2025-07-09 13:16:00.187', 10605, 2506, 39),
(9478, 'well stocked', '2025-07-09 16:20:49.958', 10605, 2509, 46),
(9492, 'Doesn\'t want to restock our vapes... claiming that the number of puffs are false.', '2025-07-10 06:33:51.342', 10605, 2510, 32),
(9496, 'Out of stock.\njust made an order, awaiting delivery.', '2025-07-10 10:21:51.458', 10605, 2511, 46),
(9506, 'prices not yet to change \nremains 2300 and 3000 for 3000 puffs and 9000 puffs respectfully ', '2025-07-10 07:57:19.451', 10605, 2512, 62),
(9509, 'fully stocked', '2025-07-10 11:06:54.635', 10605, 2513, 104),
(9515, 'They are well stocked', '2025-07-10 11:21:34.464', 10605, 2514, 22),
(9517, 'we\'ve been ordering 3000puffs and they\'re not been delivered ', '2025-07-10 08:32:58.779', 10605, 2515, 21),
(9519, 'products', '2025-07-10 11:38:26.341', 10605, 2516, 104),
(9522, 'not well stocked. have liased with the BAC and promised to place the order in the evening or by Monday ', '2025-07-10 08:46:36.406', 10605, 2517, 21),
(9524, 'They are well stocked', '2025-07-10 11:49:20.336', 10605, 2518, 22),
(9529, 'Rrp 650\nMovement is quite slow at the moment', '2025-07-10 11:53:14.747', 10605, 2519, 49),
(9531, 'kumetulia', '2025-07-10 08:53:49.983', 10605, 2520, 48),
(9533, 'placed an order for the Goldpouches', '2025-07-10 11:56:44.524', 10605, 2521, 23),
(9539, 'well stocked with pouches\nawaiting vape delivery', '2025-07-10 12:04:04.401', 10605, 2523, 46),
(9540, 'no product', '2025-07-10 09:05:57.363', 10605, 2524, 48),
(9544, 'products are moving so well', '2025-07-10 12:19:49.663', 10605, 2525, 109),
(9549, 'The 5 dot is moving  faster than the three dot.\n', '2025-07-10 09:27:35.757', 10605, 2526, 51),
(9551, 'received 20 pcs', '2025-07-10 09:28:36.646', 10605, 2527, 48),
(9557, 'making an order today', '2025-07-10 12:35:03.191', 10605, 2529, 46),
(9562, 'pushing for payments', '2025-07-10 09:46:43.768', 10605, 2530, 48),
(9564, 'welll stocked', '2025-07-10 12:48:43.011', 10605, 2531, 46),
(9567, 'Placed an order with us since they are a dealer', '2025-07-10 12:57:10.455', 10605, 2532, 23),
(9569, 'progressing on so well', '2025-07-10 12:58:42.514', 10605, 2533, 109),
(9570, 'Hart is the competitor in that market.', '2025-07-10 09:59:29.436', 10605, 2534, 51),
(9573, 'She\'s working with BAT and already started selling Velo', '2025-07-10 13:02:22.115', 10605, 2535, 35),
(9576, 'follow up on boarding.', '2025-07-10 13:17:21.482', 10605, 2536, 35),
(9580, 'test', '2025-07-10 13:28:25.786', 10605, 2537, 94),
(9582, 'engaging them in stocking out products', '2025-07-10 13:35:46.211', 10605, 2538, 35),
(9583, 'well stocked \nto place order next week ', '2025-07-10 10:35:47.909', 10605, 2539, 21),
(9586, 'waiting for the stock', '2025-07-10 13:43:05.934', 10605, 2540, 109),
(9589, 'to clear pending payment next week. requesting exchanges on slow moving flavours ', '2025-07-10 10:56:05.696', 10605, 2541, 57),
(9592, 'slow movement', '2025-07-10 14:06:07.365', 10605, 2542, 46),
(9598, 'was pushing for payment gladly it has been paid ', '2025-07-10 11:28:43.718', 10605, 2543, 39),
(9607, 'velo is the competitor selling at 450', '2025-07-10 11:57:18.457', 10605, 2545, 51),
(9608, 'Stock out', '2025-07-10 15:01:34.732', 10605, 2546, 46),
(9612, 'very well stocked.', '2025-07-10 12:14:46.883', 10605, 2547, 57),
(9617, ' waiting for 9000 Puffs ', '2025-07-10 12:21:02.946', 10605, 2548, 62),
(9623, 'The products are well displayed. The pouches are moving faster.', '2025-07-10 12:29:52.343', 10605, 2550, 51),
(9630, 'will order sartuday ', '2025-07-10 13:04:58.420', 10605, 2553, 62),
(9632, 'order placed', '2025-07-10 16:13:35.342', 10605, 2554, 20),
(9635, 'Stocks selling very well at this outlet.', '2025-07-10 13:47:06.437', 10605, 2556, 57),
(9638, 'gold pouch selling we are leading in this outlet more than likes of sky and booster ', '2025-07-10 14:04:00.100', 10605, 2557, 62),
(9640, 'stocked', '2025-07-10 18:13:42.327', 10605, 2558, 20),
(9643, 'tes', '2025-07-10 22:52:25.861', 10605, 2559, 94),
(9644, 'tes', '2025-07-10 22:52:38.364', 10605, 2560, 94),
(9645, 'tes', '2025-07-10 22:55:16.778', 10605, 2561, 94),
(9656, 'out of stock\ndecided not stock since product is slow moving', '2025-07-11 06:45:56.495', 10605, 2562, 46),
(9657, '1750 3000puffs \n23009000puff', '2025-07-11 09:47:22.740', 10605, 2563, 104),
(9660, 'slow moving ', '2025-07-11 06:49:50.302', 10605, 2564, 62),
(9674, 'they\'re well stocked ', '2025-07-11 07:42:40.746', 10605, 2565, 21),
(9685, 'waiting on a pending order from their HQ ', '2025-07-11 08:05:38.061', 10605, 2566, 35),
(9686, 'slow moving well stocked', '2025-07-11 11:11:09.646', 10605, 2567, 104),
(9687, 'Met with Cliff the owner of Magnum over stocking of Vapes at his premises. he\'s get back to me after market survey especially in nrb that is his response ', '2025-07-11 08:14:30.177', 10605, 2568, 35),
(9697, 'order will arrive tomorrow ', '2025-07-11 08:25:17.795', 10605, 2569, 62),
(9707, 'no sales yet', '2025-07-11 08:34:44.898', 10605, 2570, 109),
(9712, 'well stocked ', '2025-07-11 08:35:51.417', 10605, 2571, 63),
(9718, 'sales in the outlet have picked..will place an order hopefully next month ', '2025-07-11 08:49:13.706', 10605, 2572, 23),
(9719, 'we placed an order I hope it be delivered since they deliver less of what we always order ', '2025-07-11 08:49:20.825', 10605, 2573, 47),
(9721, 'made an order of 60 pouches 5 dots', '2025-07-11 08:49:51.727', 10605, 2574, 35),
(9724, 'They are well stocked', '2025-07-11 11:51:14.790', 10605, 2575, 22),
(9735, '6ḿ', '2025-07-11 09:09:43.113', 10605, 2576, 30),
(9744, 'well stocked ', '2025-07-11 09:22:51.799', 10605, 2577, 63),
(9746, 'Follow-up to see if restock ', '2025-07-11 09:23:44.779', 10605, 2578, 40),
(9749, 'Following up on boarding ', '2025-07-11 09:26:42.426', 10605, 2579, 35),
(9752, 'placed their order for vapes and Pouches ', '2025-07-11 09:31:46.667', 10605, 2580, 23),
(9764, 'follow up on boarding the outlet, met Samantha, she\'s still not ready to stock despite reffing her clients to tipsy tidings liquor store ', '2025-07-11 09:49:26.175', 10605, 2581, 35),
(9766, 'order by tomorrow latest ', '2025-07-11 09:50:10.703', 10605, 2582, 46),
(9767, 'order will be placed tomorrow ', '2025-07-11 09:50:20.202', 10605, 2583, 62),
(9769, 'Awaiting return of 9000 puffs to place order', '2025-07-11 09:51:58.329', 10605, 2584, 57),
(9772, 'They are well stocke', '2025-07-11 12:54:01.630', 10605, 2585, 22),
(9782, 'well Stocked ', '2025-07-11 10:02:30.016', 10605, 2586, 21),
(9788, 'Very well stocked, velo pouch now being stocked', '2025-07-11 10:27:20.157', 10605, 2587, 57),
(9796, 'to pick the cheque tomorrow ', '2025-07-11 10:32:03.650', 10605, 2588, 12),
(9807, 'moving slowly velo moving very fast ', '2025-07-11 10:54:48.488', 10605, 2589, 63),
(9810, 'stocked ', '2025-07-11 10:55:48.097', 10605, 2590, 46),
(9812, 'to do an order for the gold pouches and 3000 puffs. ', '2025-07-11 11:00:25.407', 10605, 2591, 12),
(9816, 'They will place an order after making their payment.', '2025-07-11 11:03:39.513', 10605, 2592, 23),
(9819, 'They\'re well stocked ', '2025-07-11 11:06:19.001', 10605, 2593, 21),
(9823, 'very well stocked. pouch slow moving', '2025-07-11 11:12:11.492', 10605, 2594, 57),
(9828, '3000p does better than the 9000p\none faulty (Pineapple mango mint)9000p', '2025-07-11 11:19:00.780', 10605, 2595, 114),
(9832, 'out of stock on vapes', '2025-07-11 11:28:07.159', 10605, 2596, 46),
(9834, 'well stocked with 9000puffs', '2025-07-11 11:30:31.047', 10605, 2597, 21),
(9841, 'the vapes does well 9000puffs ', '2025-07-11 11:42:12.883', 10605, 2598, 114),
(9845, 'picking the cheque on monday', '2025-07-11 12:05:45.723', 10605, 2599, 46),
(9847, 'heading to the office facilitating their exchange ', '2025-07-11 12:08:05.526', 10605, 2600, 39),
(9848, '14pcs stocks', '2025-07-11 15:09:01.689', 10605, 2601, 20),
(9851, 'Awaiting 9000 puffs to place order', '2025-07-11 12:15:24.345', 10605, 2602, 57),
(9852, 'placed an order for vapes, 11 pcs', '2025-07-11 12:20:42.433', 10605, 2603, 23),
(9856, 'selling at KSH 504 good price but the problem of displaying is more affecting them', '2025-07-11 12:33:23.787', 10605, 2604, 62),
(9858, 'well stocked ', '2025-07-11 12:40:52.657', 10605, 2605, 46),
(9862, 'moving slowly ', '2025-07-11 12:43:35.412', 10605, 2606, 63),
(9867, 'mounting needed at magunas wendani ', '2025-07-11 13:07:01.560', 10605, 2607, 63),
(9869, 'low season no sales', '2025-07-11 13:13:06.625', 10605, 2608, 57),
(9875, 'out of stock ', '2025-07-11 13:38:41.923', 10605, 2609, 46),
(9883, 'passed by for feedback ', '2025-07-11 15:40:35.184', 10605, 2610, 39),
(9888, 'Totalenegies Kiserian, they have closed down,affected with madamano ', '2025-07-11 18:55:00.118', 10605, 2611, 40),
(9890, 'trying to onboard them to stock  pouches', '2025-07-12 06:13:39.054', 10605, 2612, 46),
(9896, 'waiting for display ', '2025-07-12 06:56:00.631', 10605, 2613, 109),
(9900, 'progressing on so well', '2025-07-12 07:52:57.138', 10605, 2614, 109),
(9901, 'interested in woosh since pouches didn\'t do well', '2025-07-12 08:03:54.238', 10605, 2615, 46),
(9907, 'The display needs mounting ', '2025-07-12 08:09:26.107', 10605, 2616, 30),
(9920, 'moving slowly . protests is affecting them ', '2025-07-12 08:47:51.745', 10605, 2618, 63),
(9925, 'products moving on so well', '2025-07-12 08:54:33.012', 10605, 2619, 109),
(9927, 'The manager hasn\'t placed an order despite efforts to push for it', '2025-07-12 08:59:32.935', 10605, 2620, 30),
(9928, 'Quickmart Kiserian follow-up for order vape', '2025-07-12 09:01:06.406', 10605, 2621, 40),
(9930, 'placed another order ', '2025-07-12 09:03:33.611', 10605, 2622, 62),
(9933, 'the vapes does well in utawala branch 9000p', '2025-07-12 09:09:26.862', 10605, 2623, 114),
(9934, 'Stock not moved in two months so far ', '2025-07-12 09:09:57.692', 10605, 2624, 35),
(9936, 'following up on payment, could get him they were still closed', '2025-07-12 09:13:56.665', 10605, 2625, 35),
(9945, 'placing an order next week for 3dots and 5dots', '2025-07-12 09:27:45.112', 10605, 2626, 63),
(9952, 'They are well stocked', '2025-07-12 12:43:11.876', 10605, 2627, 22),
(9953, 'Theirvapes are still sealed and are not displaying any nicotine products. BAT sorted the issue for the outlet.', '2025-07-12 09:43:14.381', 10605, 2628, 23),
(9958, 'there are no stocks but we\'ve placed order ', '2025-07-12 10:03:50.877', 10605, 2629, 21),
(9960, 'well stocked ', '2025-07-12 10:07:39.116', 10605, 2630, 63),
(9962, 'the location is outside range in utawala branch', '2025-07-12 10:09:00.400', 10605, 2631, 114),
(9963, 'permanently closed', '2025-07-12 10:12:18.263', 10605, 2632, 114),
(9970, 'no shop', '2025-07-12 11:01:12.219', 10605, 2633, 23),
(9973, 'Following up on payments ', '2025-07-12 12:17:05.904', 10605, 2634, 57),
(9978, 'Challenge getting payment as vapes have not sold. ', '2025-07-12 12:45:37.747', 10605, 2635, 57),
(9982, 'larji Ramji haven\'t received their stock just yet. I don\'t know why coz I followed up on Thursday and adesheal agreed to send the parcel. ', '2025-07-12 14:31:32.296', 10605, 2636, 47),
(9983, 'well stocked ', '2025-07-12 14:49:55.967', 10605, 2637, 32),
(9984, 'Trying to Onboard them ', '2025-07-12 14:51:22.452', 10605, 2638, 32),
(10003, 'collecting payment ', '2025-07-14 07:22:37.620', 10605, 2639, 57),
(10005, 'products moving well especially pouches', '2025-07-14 07:29:21.592', 10605, 2640, 57);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(10009, 'following up on payments ', '2025-07-14 07:32:08.785', 10605, 2641, 57),
(10013, 'well stocked \npicking up ', '2025-07-14 07:33:38.915', 10605, 2642, 63),
(10014, 'waiting for their order', '2025-07-14 07:34:18.432', 10605, 2643, 109),
(10016, 'following up on payments.', '2025-07-14 07:36:10.450', 10605, 2644, 57),
(10019, 'They received their order on Friday ', '2025-07-14 07:41:38.955', 10605, 2645, 23),
(10021, 'no sales for a long time still having 3 vapes in stock ', '2025-07-14 07:44:52.492', 10605, 2646, 57),
(10028, 'have issues with dantra ', '2025-07-14 07:58:19.649', 10605, 2647, 62),
(10029, 'The owner is very stubborn does not want to place order on vapes', '2025-07-14 07:59:57.017', 10605, 2648, 31),
(10038, 'They are yet to receive their order placed on Thursday ', '2025-07-14 08:28:30.225', 10605, 2649, 23),
(10043, 'placed another order last weekend ', '2025-07-14 08:32:04.278', 10605, 2650, 62),
(10044, 'stocked expecting an oder by next week', '2025-07-14 08:32:30.097', 10605, 2651, 46),
(10049, 'to make payments and there\'s been sale\'s of the pouches', '2025-07-14 08:37:04.765', 10605, 2652, 35),
(10054, 'they have a high selling price even after intervention they insist it\'s okay with them ', '2025-07-14 08:43:45.713', 10605, 2653, 35),
(10057, 'still stocked', '2025-07-14 08:48:24.836', 10605, 2654, 46),
(10060, 'They are well stocked', '2025-07-14 08:51:12.194', 10605, 2655, 22),
(10068, 'The vapes and pouches are moving slowly. ', '2025-07-14 09:01:13.470', 10605, 2656, 51),
(10070, 'have collected their order ', '2025-07-14 09:08:31.576', 10605, 2657, 39),
(10073, 'Still follow up on this outlet boarding ', '2025-07-14 09:11:36.589', 10605, 2658, 35),
(10075, 'stocked\nwell displayed\nno competition.', '2025-07-14 09:11:54.656', 10605, 2659, 64),
(10084, 'They are well stocked', '2025-07-14 09:18:14.109', 10605, 2660, 22),
(10087, 'The Goldpouches in the outlet have picked in sales. ', '2025-07-14 09:19:53.481', 10605, 2661, 23),
(10093, 'They don\'t have stocked', '2025-07-14 09:23:44.334', 10605, 2662, 22),
(10095, 'well stocked ', '2025-07-14 09:25:09.336', 10605, 2663, 63),
(10107, 'well stocked ', '2025-07-14 09:41:57.557', 10605, 2664, 32),
(10108, 'stocked\nwell displayed.', '2025-07-14 09:44:16.051', 10605, 2665, 64),
(10109, 'Trying to Onboard them.', '2025-07-14 09:46:29.866', 10605, 2666, 32),
(10115, 'received 10 pieces of minty snow, placed an order of 30 pcs', '2025-07-14 09:52:59.312', 10605, 2667, 35),
(10117, 'to pick the cheque from him today. ', '2025-07-14 09:54:07.879', 10605, 2668, 12),
(10118, 'received the order', '2025-07-14 09:54:24.355', 10605, 2669, 48),
(10125, 'the movement is okay ', '2025-07-14 10:01:44.415', 10605, 2670, 39),
(10131, 'selling prices \n9000 puffs KSH 1799\n3000puffs KSH 1429\ngold pouches KSH 504\n\ngood prices ', '2025-07-14 10:08:07.517', 10605, 2671, 62),
(10135, 'stocked\nwell displayed\nno competition', '2025-07-14 10:10:05.704', 10605, 2672, 64),
(10138, 'They are well stocked', '2025-07-14 10:11:30.151', 10605, 2673, 22),
(10140, 'velo is the competitor. ', '2025-07-14 10:12:35.070', 10605, 2674, 51),
(10145, 'order through Titus Finance ', '2025-07-14 10:15:43.725', 10605, 2675, 23),
(10147, 'well stocked ', '2025-07-14 10:16:39.303', 10605, 2676, 63),
(10155, 'they\'re well stocked ', '2025-07-14 10:27:46.849', 10605, 2677, 21),
(10158, 'The pouches are moving quickly.', '2025-07-14 10:28:39.083', 10605, 2678, 51),
(10160, 'Follow up on reorders on stock level\'s ', '2025-07-14 10:30:51.195', 10605, 2679, 35),
(10162, 'sold one pouches on Sartaday ', '2025-07-14 10:32:08.873', 10605, 2680, 48),
(10163, 'waiting for their order ', '2025-07-14 10:34:15.585', 10605, 2681, 109),
(10172, 'Not ordering at the moment ', '2025-07-14 10:46:24.817', 10605, 2682, 30),
(10173, 'it\'s slaw', '2025-07-14 10:46:57.467', 10605, 2683, 48),
(10177, 'The supervisor is pushing for payment to be made then place another order ', '2025-07-14 10:49:23.496', 10605, 2684, 23),
(10178, 'pushing them to display if not we collect our display back', '2025-07-14 10:49:45.443', 10605, 2685, 39),
(10185, 'to follow up on payment ', '2025-07-14 11:10:01.708', 10605, 2686, 12),
(10190, 'their prices have not changed for the 3000 puffs', '2025-07-14 11:13:09.046', 10605, 2687, 23),
(10191, 'well stocked', '2025-07-14 11:14:50.507', 10605, 2688, 46),
(10197, 'have pending debt', '2025-07-14 11:22:43.217', 10605, 2689, 62),
(10202, 'Received their order on Friday. The prices have not been changed in their system for the 3000 puffs.', '2025-07-14 11:41:14.744', 10605, 2690, 23),
(10203, 'well stocked ', '2025-07-14 11:42:14.233', 10605, 2691, 46),
(10206, 'well stocked', '2025-07-14 11:55:20.755', 10605, 2692, 32),
(10207, 'finished stock yesterday but needs to pay then place another order. I\'m \n following up on payment. the boss is not around. ', '2025-07-14 11:57:31.782', 10605, 2693, 47),
(10222, 'received velo 2 dots 2 pcs\n3 dots 4 pcs\nselling both at 450', '2025-07-14 12:16:46.109', 10605, 2694, 48),
(10224, 'order will be placed in presence of manager ', '2025-07-14 12:27:56.016', 10605, 2695, 62),
(10226, 'they are stock out. I\'m pressing them to pay me. then will order ', '2025-07-14 12:30:19.033', 10605, 2696, 47),
(10229, 'fully stocked', '2025-07-14 12:34:21.829', 10605, 2697, 104),
(10233, 'will order this week. paying Today ', '2025-07-14 12:49:58.837', 10605, 2698, 47),
(10238, 'well stocked ', '2025-07-14 12:55:26.605', 10605, 2699, 21),
(10247, 'ordered received today. 50pcs gold pouches and 34pcs vapes', '2025-07-14 13:28:17.379', 10605, 2700, 47),
(10252, 'have enough stocks ', '2025-07-14 13:46:50.120', 10605, 2701, 62),
(10263, '9000p does well', '2025-07-14 14:18:43.157', 10605, 2702, 114),
(10268, 'well stocked ', '2025-07-14 14:27:26.832', 10605, 2703, 32),
(10272, 'well stocked on pouches ', '2025-07-14 14:34:12.266', 10605, 2704, 32),
(10276, 'one was a faulty, former 2500p\na client bought the 3000p passion fruit mint but returned it back .\nit was choking \n', '2025-07-14 14:42:46.686', 10605, 2705, 114),
(10277, 'to follow up on our vapes', '2025-07-14 14:48:17.847', 10605, 2706, 114),
(10282, 'engaging the outlet for boarding ', '2025-07-14 14:52:49.893', 10605, 2707, 35),
(10284, 'client gave me their order last week but the flavours are not available. we are waiting to restock the flavors he wants. ', '2025-07-14 14:58:05.361', 10605, 2708, 47),
(10302, 'waiting for display ', '2025-07-15 06:42:46.671', 10605, 2709, 109),
(10314, 'products moving well', '2025-07-15 08:13:00.835', 10605, 2710, 109),
(10317, 'thy stocked up velo retailers at 430 and 580 respectively ', '2025-07-15 08:25:42.086', 10605, 2711, 35),
(10327, 'talked to Rajesh once again concerning our products, he\'s promised to talk to their outlets selling liquor before listing ', '2025-07-15 08:49:58.666', 10605, 2712, 35),
(10329, 'Trying to Onboard them ', '2025-07-15 08:56:01.612', 10605, 2713, 32),
(10331, 'pushing for a restock ', '2025-07-15 08:59:11.365', 10605, 2714, 35),
(10332, 'fully stocked ', '2025-07-15 09:04:54.859', 10605, 2715, 104),
(10341, 'slow moving, but still pushing', '2025-07-15 09:33:44.154', 10605, 2716, 46),
(10345, 'They\'re well stocked. we\'ve placed order for the missing flavors ', '2025-07-15 09:38:15.346', 10605, 2717, 21),
(10353, 'progressing well', '2025-07-15 09:45:54.558', 10605, 2718, 109),
(10357, 'they have over stayed without paying last order \nI was instructed not to make order without payments fast', '2025-07-15 09:53:20.728', 10605, 2719, 48),
(10361, 'The outlet is well stocked... To revusit for an order next week ', '2025-07-15 09:56:21.409', 10605, 2720, 30),
(10363, 'well stocked for now ', '2025-07-15 09:56:35.534', 10605, 2721, 7),
(10367, 'will get them a display ', '2025-07-15 10:00:48.013', 10605, 2722, 32),
(10368, 'They are well stocked', '2025-07-15 10:02:37.958', 10605, 2723, 22),
(10372, 'they need an exchange of 3dots', '2025-07-15 10:07:18.047', 10605, 2724, 63),
(10376, 'their is velo \nin 2 containers\n1 with 15pcs @350\nthe other 20 pcs @450\nour pouches is selling@ 550', '2025-07-15 10:12:57.876', 10605, 2725, 48),
(10379, 'out of stock with our products, will be collecting our display if thy don\'t make a reorder ', '2025-07-15 10:14:47.881', 10605, 2726, 35),
(10383, 'stocked\nwell displayed\nrrp @550 for GP and 2000/1570 for Vapes.', '2025-07-15 10:18:10.641', 10605, 2727, 64),
(10384, 'looking forward to onboard them', '2025-07-15 10:22:43.286', 10605, 2728, 114),
(10387, 'looking forward to onboard them ', '2025-07-15 10:24:05.020', 10605, 2729, 114),
(10390, 'still has products..\npushing for a re order', '2025-07-15 10:33:26.519', 10605, 2730, 46),
(10393, 'the movement is very slow due to the pricing ', '2025-07-15 10:36:37.843', 10605, 2731, 39),
(10402, 'To collect cheque in the course of the day', '2025-07-15 10:41:04.462', 10605, 2732, 49),
(10403, '*well stocked for now \n*competitetor hart,goat,boaster( caffeine),sky', '2025-07-15 10:41:52.606', 10605, 2733, 7),
(10408, 'They\'re still to recieve order for 3000puffs', '2025-07-15 10:46:39.972', 10605, 2734, 21),
(10409, 'to uplift from their main brunch today ', '2025-07-15 10:46:57.904', 10605, 2735, 49),
(10412, 'placing an order for 5dots this week ', '2025-07-15 10:48:22.542', 10605, 2736, 63),
(10413, 'The vapes are moving slowly .', '2025-07-15 10:53:55.160', 10605, 2737, 51),
(10414, 'received their order and placed another order of 30 pcs today', '2025-07-15 10:57:19.419', 10605, 2738, 62),
(10417, 'clased', '2025-07-15 10:59:15.491', 10605, 2739, 48),
(10418, 'the outlet was permanently closed', '2025-07-15 10:59:35.256', 10605, 2740, 114),
(10421, 'Trying to Onboard them ', '2025-07-15 11:01:53.752', 10605, 2741, 32),
(10423, 'The 3000puffs are currently removed from the shelves.', '2025-07-15 11:04:38.120', 10605, 2742, 51),
(10424, 'Trying to Onboard them ', '2025-07-15 11:05:26.463', 10605, 2743, 32),
(10429, 'kumetulia tu', '2025-07-15 11:12:16.572', 10605, 2744, 48),
(10430, 'Extremely slow movement ', '2025-07-15 11:12:17.347', 10605, 2745, 49),
(10435, 'Well stocked ', '2025-07-15 11:21:06.067', 10605, 2746, 21),
(10440, 'still stocked ', '2025-07-15 11:29:22.212', 10605, 2747, 20),
(10446, 'totally well stocked with vapes and pouches ', '2025-07-15 11:38:09.095', 10605, 2748, 63),
(10450, 'They are well stocked', '2025-07-15 11:39:53.522', 10605, 2749, 22),
(10451, 'they need am exchange of a vape that was a faulty to restock back our vapes', '2025-07-15 11:40:38.044', 10605, 2750, 114),
(10452, 'We are placing order for 9000puffs ', '2025-07-15 11:41:15.613', 10605, 2751, 22),
(10453, 'Still stocked', '2025-07-15 11:41:44.824', 10605, 2752, 30),
(10456, '*competitetor velo', '2025-07-15 11:48:12.776', 10605, 2753, 7),
(10460, 'well stocked. we will place order for the sold out flavors on Saturday ', '2025-07-15 12:00:08.444', 10605, 2754, 21),
(10463, 'well stocked ', '2025-07-15 12:01:37.593', 10605, 2755, 63),
(10465, 'Good movement ', '2025-07-15 12:02:52.508', 10605, 2756, 49),
(10468, 'They are well stocked', '2025-07-15 12:04:59.441', 10605, 2757, 22),
(10472, 'will order vapes by the end of the week', '2025-07-15 12:06:13.135', 10605, 2758, 47),
(10476, 'low on stock ', '2025-07-15 12:14:28.659', 10605, 2759, 46),
(10482, 'Still well stocked ', '2025-07-15 12:31:28.427', 10605, 2760, 30),
(10486, 'following up on pending payment.', '2025-07-15 12:37:22.511', 10605, 2761, 57),
(10489, 'Branch BAC has refused to place order he keeps telling me to write codes but never sends to their HQ I need assistance ', '2025-07-15 12:45:26.109', 10605, 2762, 36),
(10493, 'moving slowly but picking ', '2025-07-15 12:48:05.553', 10605, 2763, 63),
(10498, 'they have received yesterday\'s order ', '2025-07-15 13:05:11.019', 10605, 2764, 62),
(10499, '9000 puffs is out of stocks', '2025-07-15 13:14:32.588', 10605, 2765, 20),
(10502, 'Sales slowly picking up.', '2025-07-15 13:16:38.416', 10605, 2766, 57),
(10505, 'to pay today ', '2025-07-15 13:29:21.752', 10605, 2767, 47),
(10506, 'Fair movement ', '2025-07-15 13:31:16.213', 10605, 2768, 49),
(10507, 'mathai supermarket Meru closes. there are rumours that there is maandamano ', '2025-07-15 13:32:28.136', 10605, 2769, 47),
(10510, 'the vapes.perfom poorly ', '2025-07-15 13:38:39.400', 10605, 2770, 114),
(10513, '\nThe bonjour owner has committed to pay the pending amount in the evening.', '2025-07-15 13:42:41.777', 10605, 2771, 23),
(10515, 'placing order', '2025-07-15 13:50:25.213', 10605, 2772, 57),
(10516, 'the vapes were mishandled and the stock was taken off by the police ', '2025-07-15 14:23:39.051', 10605, 2773, 114),
(10521, 'Just received their stock, to collect payment tomorrow ', '2025-07-15 14:54:29.900', 10605, 2774, 49),
(10524, 'Trying to Onboard them ', '2025-07-15 15:17:18.260', 10605, 2775, 32),
(10526, 'To place order next week ', '2025-07-15 15:23:38.197', 10605, 2776, 57),
(10530, 'the client is appset for not delivery is order Vapes ', '2025-07-15 16:34:00.439', 10605, 2777, 40),
(10548, 'well stocked\nwell displayed...', '2025-07-16 06:18:05.684', 10605, 2778, 64),
(10549, 'stocked in all SKUs\ncompetition:velo', '2025-07-16 06:24:06.587', 10605, 2779, 64),
(10551, 'products are moving slow', '2025-07-16 06:31:11.164', 10605, 2780, 109),
(10556, 'expecting an order this week ', '2025-07-16 06:52:54.782', 10605, 2781, 46),
(10557, 'well stocked\nwell displayed', '2025-07-16 06:54:42.111', 10605, 2782, 64),
(10563, 'making follow up on payment, requested till weekend ', '2025-07-16 07:04:54.656', 10605, 2783, 35),
(10578, 'engaging the outlet from for boarding. bado ni mgumu, will revisit ', '2025-07-16 07:58:16.065', 10605, 2784, 35),
(10588, 'placed an order for vapes', '2025-07-16 08:16:14.065', 10605, 2785, 63),
(10603, 'They are well stocked', '2025-07-16 08:54:02.622', 10605, 2786, 22),
(10605, 'I can\'t check In to the outlet without merchandiser documents ', '2025-07-16 08:58:39.178', 10605, 2787, 63),
(10612, 'The products are moving quickly. ', '2025-07-16 09:15:23.300', 10605, 2788, 51),
(10619, 'They are well stocked', '2025-07-16 09:18:00.068', 10605, 2789, 22),
(10623, 'well stocked ', '2025-07-16 09:22:50.494', 10605, 2790, 63),
(10625, 'the flow of customers is slaw', '2025-07-16 09:24:08.533', 10605, 2791, 48),
(10630, 'Rubis HQ staff are doing auditing in the outlet. They will place their order on Friday for the vapes.', '2025-07-16 09:34:16.425', 10605, 2792, 23),
(10634, 'The pouches are moving slowly. ', '2025-07-16 09:43:23.992', 10605, 2793, 51),
(10636, 'minty snow is moving quickly. They will place an order tomorrow ', '2025-07-16 09:46:48.249', 10605, 2794, 51),
(10638, 'They well stocked', '2025-07-16 09:47:19.559', 10605, 2795, 22),
(10645, 'it\'s a new outlet we want to onboard', '2025-07-16 09:59:03.547', 10605, 2796, 22),
(10646, 'placed order but they are saying HQ have no stocks ', '2025-07-16 09:59:14.838', 10605, 2797, 62),
(10654, 'well stocked with 3k puffs and 9k puffs \n', '2025-07-16 10:10:25.294', 10605, 2798, 63),
(10660, 'well stocked ', '2025-07-16 10:15:44.449', 10605, 2799, 21),
(10673, 'received their order ', '2025-07-16 10:33:03.004', 10605, 2800, 62),
(10678, 'The supervisor is giving an order in the evening when she comes back.', '2025-07-16 10:34:48.951', 10605, 2801, 23),
(10683, 'well stocked', '2025-07-16 10:45:13.105', 10605, 2802, 46),
(10687, 'moving slowly ', '2025-07-16 10:50:34.289', 10605, 2803, 62),
(10688, 'Follow-up for order vapes ', '2025-07-16 10:52:00.089', 10605, 2804, 40),
(10690, 'Follow-up for order next week ', '2025-07-16 10:54:56.614', 10605, 2805, 40),
(10693, 'look forward yo see weather she reserved order of Pouches ', '2025-07-16 11:02:23.923', 10605, 2806, 40),
(10696, 'expecting an order by this week', '2025-07-16 11:07:39.170', 10605, 2807, 46),
(10697, 'we will do an exchange for the 9000 puffs with Goldpouches.', '2025-07-16 11:08:49.113', 10605, 2808, 23),
(10699, 'Sales have slowed down at this outlet. ', '2025-07-16 11:16:58.177', 10605, 2809, 57),
(10701, 'well stocked ', '2025-07-16 11:18:50.081', 10605, 2810, 46),
(10709, 'kuko slaw', '2025-07-16 11:26:08.682', 10605, 2811, 48),
(10711, 'moving at a lower pace ', '2025-07-16 11:28:26.997', 10605, 2812, 62),
(10713, 'no sale this week', '2025-07-16 11:40:51.926', 10605, 2813, 48),
(10717, 'Very well stocked 210pcs 3000 puffs in stock. Still awaiting B2C payment. ', '2025-07-16 11:42:39.639', 10605, 2814, 57),
(10719, 'waiting on the displays', '2025-07-16 11:44:10.862', 10605, 2815, 104),
(10720, 'I\'m waiting for the owner since she has been avoiding my phone calls and she has a huge bebt and is running out of stock ', '2025-07-16 11:52:25.444', 10605, 2816, 39),
(10722, 'sales for the 3000 puffs are performing well in the outlet. \n\nkindly note I was in the outlet for around 40 mins then was disrupted bt the app.', '2025-07-16 11:55:00.626', 10605, 2817, 23),
(10724, 'they have no stocks and they\'re not placing order this week, they\'ve promised to place as from next week. ', '2025-07-16 12:01:40.540', 10605, 2818, 21),
(10731, 'well stocked', '2025-07-16 12:13:41.831', 10605, 2819, 46),
(10733, 'vapes movent is slow', '2025-07-16 12:16:14.233', 10605, 2820, 30),
(10735, 'placed order Monday ', '2025-07-16 12:20:06.647', 10605, 2821, 62),
(10736, 'following up on onboarding them', '2025-07-16 12:21:31.210', 10605, 2822, 114),
(10751, 'well stocked', '2025-07-16 12:47:50.031', 10605, 2823, 46),
(10754, 'Really pushing for return of 9000 puffs to place order ', '2025-07-16 12:49:10.578', 10605, 2824, 57),
(10758, 'asking is ask for 20 pcs can be asorted', '2025-07-16 12:54:41.155', 10605, 2825, 48),
(10759, 'asking is ask for 20 pcs can be asorted', '2025-07-16 12:54:50.222', 10605, 2826, 48),
(10767, 'order done for pouches and 3000 puffs', '2025-07-16 13:35:55.887', 10605, 2827, 20),
(10800, 'following up on sales of pouches. couldn\'t get to the owner this morning to check in the evening ', '2025-07-17 06:57:14.384', 10605, 2828, 35),
(10803, 'placing orders today ', '2025-07-17 07:27:21.791', 10605, 2829, 62),
(10818, 'well stocked\nwell displayed\nmovement:slow\ncompetition:none\nrrp @1570 and @500', '2025-07-17 07:56:52.218', 10605, 2830, 64),
(10825, 'well stocked in GP\nWell displayed\nplaced order 15th...\ncompetition:booster\nmovement:okey', '2025-07-17 08:29:42.697', 10605, 2831, 64),
(10834, 'well stocked', '2025-07-17 08:47:56.694', 10605, 2832, 22),
(10848, 'collection of payment ', '2025-07-17 09:02:41.431', 10605, 2833, 49),
(10850, 'received their order on Tuesday ', '2025-07-17 09:04:20.275', 10605, 2834, 62),
(10851, '*well stocked for now', '2025-07-17 09:04:44.434', 10605, 2835, 7),
(10866, 'well stocked ', '2025-07-17 09:20:07.577', 10605, 2836, 46),
(10879, 'to push for payment on the balance remaining. ', '2025-07-17 09:29:23.763', 10605, 2837, 12),
(10881, 'low on stock', '2025-07-17 09:29:32.456', 10605, 2838, 46),
(10885, 'well stocked ', '2025-07-17 09:41:40.679', 10605, 2839, 46),
(10892, '*product moving well ', '2025-07-17 09:46:19.909', 10605, 2840, 7),
(10896, 'following up on whether they received their order. ', '2025-07-17 09:47:37.967', 10605, 2841, 57),
(10897, 'movement is slow requesting for a display ', '2025-07-17 09:47:49.628', 10605, 2842, 30),
(10902, 'follow up on payments, stocks slow but moving ', '2025-07-17 09:54:46.164', 10605, 2843, 35),
(10905, 'They are well stocked', '2025-07-17 09:56:13.182', 10605, 2844, 22),
(10907, 'made follow up on boarding because she outsources her vapes from the supermarket but still not ready to stock them', '2025-07-17 09:58:19.711', 10605, 2845, 35),
(10913, 'well stocked \nprogressing so well ', '2025-07-17 10:07:22.780', 10605, 2846, 109),
(10916, 'Following up with the manager and Toris over some back office issue', '2025-07-17 10:12:12.387', 10605, 2847, 35),
(10918, 'Totally closed kindly remove from my retail list', '2025-07-17 10:14:55.468', 10605, 2848, 35),
(10922, 'well stocked\nslow movement ', '2025-07-17 10:19:13.466', 10605, 2849, 109),
(10935, 'Fair movement ', '2025-07-17 10:59:14.695', 10605, 2850, 49),
(10937, 'They are well stocked', '2025-07-17 11:01:13.758', 10605, 2851, 22),
(10939, 'Fair movement ', '2025-07-17 11:06:43.128', 10605, 2852, 49),
(10942, 'no sales at this outlet causing challenges with payment collection. ', '2025-07-17 11:10:37.729', 10605, 2853, 57),
(10943, 'well stocked \nin Need of a display ', '2025-07-17 11:11:36.941', 10605, 2854, 46),
(10951, 'no sales at all for 3 months', '2025-07-17 11:35:59.625', 10605, 2855, 57),
(10956, '*to place order next week \n*competitetor hart,velo', '2025-07-17 11:42:09.032', 10605, 2856, 7),
(10961, 'Goldpouch sales in outlet are picking well.', '2025-07-17 11:54:30.739', 10605, 2857, 23),
(10963, 'they have an issue to be resolved with to continue placing orders', '2025-07-17 11:57:48.346', 10605, 2858, 114),
(10969, 'pushing for payment ', '2025-07-17 12:05:30.335', 10605, 2859, 39),
(10976, 'slow moving due to problem of displaying ', '2025-07-17 12:21:47.163', 10605, 2860, 62),
(10983, 'well displayed ', '2025-07-17 12:32:51.599', 10605, 2861, 46),
(10985, 'well stocked, needs a dislay', '2025-07-17 12:43:04.108', 10605, 2862, 46),
(10987, 'velo is our competitor in this outlet ', '2025-07-17 12:47:03.805', 10605, 2863, 62),
(10996, 'convincing them to get the vapes', '2025-07-17 13:32:51.562', 10605, 2864, 49),
(10998, 'stocked on pouches ', '2025-07-17 13:36:35.281', 10605, 2865, 49),
(10999, 'stocked on Velo', '2025-07-17 13:36:45.431', 10605, 2866, 49),
(11004, '9000p did better than the 3000p', '2025-07-17 13:43:27.170', 10605, 2867, 114),
(11010, '1,unable to order due to slow movement \n2, their prices have remained high even after negotiations ', '2025-07-17 13:57:47.694', 10605, 2868, 62),
(11014, 'following up on restocking our vapes', '2025-07-17 14:10:13.317', 10605, 2869, 114),
(11019, '9000 puffs moving fast but low in stocks', '2025-07-17 14:53:56.056', 10605, 2870, 26),
(11025, 'not yet stocked', '2025-07-17 15:32:51.417', 10605, 2871, 20),
(11028, 'order to be placed tomorrow ', '2025-07-17 15:43:23.290', 10605, 2872, 20),
(11029, 'stocked on 3000 puffs and pouches', '2025-07-17 15:46:24.434', 10605, 2873, 20),
(11035, 'since they don\'t display selling becomes more difficult for them ', '2025-07-18 06:45:49.234', 10605, 2874, 62),
(11038, 'well stocked\nwell displayed\nno competition\nrrp @550 ,@1570 and @2000', '2025-07-18 07:00:24.509', 10605, 2875, 64),
(11040, 'product slow moving', '2025-07-18 07:08:44.320', 10605, 2876, 46),
(11046, 'stocked in 3000 and 9000 puffs\nwell displayed\nno competition\nmovement:okey', '2025-07-18 07:28:14.912', 10605, 2877, 64),
(11049, 'well stocked\n\nwell displayed', '2025-07-18 07:35:38.658', 10605, 2878, 64),
(11066, 'well stocked \ngood progress ', '2025-07-18 08:10:52.635', 10605, 2879, 109),
(11067, 'still stocked ', '2025-07-18 08:18:21.331', 10605, 2880, 20),
(11075, '3000 puffs  has not been delivered in outlet', '2025-07-18 08:29:16.674', 10605, 2881, 26),
(11079, 'They are well stovked', '2025-07-18 08:46:58.541', 10605, 2882, 22),
(11083, 'placing orders today ', '2025-07-18 08:49:34.704', 10605, 2883, 62),
(11094, 'stocked', '2025-07-18 09:26:28.197', 10605, 2884, 46),
(11095, 'order in process ', '2025-07-18 09:31:42.494', 10605, 2885, 104),
(11099, 'Extremely slow movement ', '2025-07-18 09:32:57.587', 10605, 2886, 49),
(11108, 'Well stocked ', '2025-07-18 09:44:28.705', 10605, 2887, 30),
(11112, 'They are well stocked', '2025-07-18 09:53:45.449', 10605, 2888, 22),
(11115, 'clossed ', '2025-07-18 10:00:08.115', 10605, 2889, 48),
(11120, 'waiting for an order from them', '2025-07-18 10:09:40.292', 10605, 2890, 111),
(11121, 'waiting for order', '2025-07-18 10:11:07.819', 10605, 2891, 111),
(11122, 'pushing for 9k puff order', '2025-07-18 10:11:23.139', 10605, 2892, 48),
(11124, 'They don\'t have stockes', '2025-07-18 10:19:08.639', 10605, 2893, 22),
(11130, 'well stocked \nproducts are moving slow', '2025-07-18 10:24:43.493', 10605, 2894, 109),
(11132, 'always placing orders but none will arrive \neven today we have placed order ', '2025-07-18 10:29:40.211', 10605, 2895, 62),
(11145, 'moving slowly but picking up ', '2025-07-18 10:50:08.547', 10605, 2896, 63),
(11151, 'products progressing on so well', '2025-07-18 11:08:36.376', 10605, 2897, 109),
(11154, 'well stocked \nprogressing on so well', '2025-07-18 11:15:39.572', 10605, 2898, 109),
(11159, 'well stocked ', '2025-07-18 11:29:41.165', 10605, 2899, 46),
(11163, 'Pouches not yet listed', '2025-07-18 11:30:52.127', 10605, 2900, 30),
(11165, 'manager said until next month is when we will place orders ', '2025-07-18 11:33:48.823', 10605, 2901, 62),
(11170, 'their faulty was exchanged ', '2025-07-18 11:59:50.931', 10605, 2902, 114),
(11172, 'made an oder', '2025-07-18 12:10:24.536', 10605, 2903, 48),
(11173, 'Order placed on 9th july is yet to be delivered ', '2025-07-18 12:10:37.833', 10605, 2904, 30),
(11180, 'Monday will place order with dantra ', '2025-07-18 12:29:25.728', 10605, 2905, 62),
(11213, 'we placed order with dantra and yet to arrive ', '2025-07-19 07:02:30.053', 10605, 2906, 62),
(11225, 'stocked in vapes\nwell displayed\ncompetition:Gogo', '2025-07-19 08:07:17.043', 10605, 2907, 64),
(11236, 'products moving on so well', '2025-07-19 08:22:55.470', 10605, 2908, 109),
(11250, 'full stocked', '2025-07-19 08:47:15.391', 10605, 2909, 104),
(11252, 'well stocked ', '2025-07-19 08:47:56.289', 10605, 2910, 46),
(11255, 'fully stocked ', '2025-07-19 08:55:20.182', 10605, 2911, 104),
(11260, 'have all the flavors available at HQ', '2025-07-19 09:00:48.890', 10605, 2912, 62),
(11261, 'Waiting item movement to pick', '2025-07-19 09:01:28.971', 10605, 2913, 30),
(11264, 'well stocked\nwell displayed', '2025-07-19 09:06:16.595', 10605, 2914, 64),
(11284, 'we have placed order today ', '2025-07-19 09:30:55.362', 10605, 2915, 62),
(11286, 'well stocked ', '2025-07-19 09:31:11.842', 10605, 2916, 63),
(11295, 'well stocked ', '2025-07-19 10:02:12.133', 10605, 2917, 63),
(11298, 'Slow movement of products, checked in for payment too', '2025-07-19 10:06:38.602', 10605, 2918, 35),
(11301, 'well stocked ', '2025-07-19 10:21:16.561', 10605, 2919, 63),
(11303, 'follow up on boarding', '2025-07-19 10:51:29.561', 10605, 2920, 35),
(11315, 'To place an order next week ', '2025-07-19 13:04:45.892', 10605, 2921, 30),
(11319, 'activation', '2025-07-19 16:26:31.588', 10605, 2922, 57),
(0, 'test', '2025-08-02 15:59:45.131', 10605, 2923, 94),
(2147483647, NULL, '2025-08-10 21:50:37.584', 10605, 2931, 0),
(7, NULL, '2025-08-10 22:00:52.546', 10605, 2933, 0),
(6, 'Test comment from curl', '2025-08-10 22:04:40.972', 10605, 2934, 0),
(NULL, 'FEEDBACK TEST COMMENT', '2025-08-10 22:06:11.856', 10605, 2935, 0),
(NULL, 'TEST SALESREP MAPPING', '2025-08-10 22:09:04.712', 10605, 2936, 94),
(NULL, 'TEST FLEXIBLE MAPPING', '2025-08-10 22:15:48.546', 10605, 2938, 94),
(NULL, 'FLUTTER TEST EXTRACTION', '2025-08-10 22:20:45.249', 10605, 2939, 94),
(NULL, 'CHECK FLUTTER DATA', '2025-08-10 22:22:34.787', 10605, 2940, 94),
(NULL, 'AUDIT TEST - FEEDBACK COMMENT', '2025-08-10 22:28:37.752', 10605, 2941, 94),
(NULL, 'FINAL TEST - FEEDBACK COMMENT', '2025-08-10 22:31:19.306', 10605, 2942, 94),
(NULL, 'this', '2025-08-10 23:35:00.923', 10605, 2943, 94),
(NULL, 'REVIEW TEST - FEEDBACK', '2025-08-10 22:40:28.996', 10605, 2944, 94),
(NULL, 'BACKWARD COMPATIBILITY TEST', '2025-08-10 22:41:24.376', 10605, 2945, 94),
(NULL, 'non', '2025-08-10 23:51:33.600', 10605, 2946, 94),
(NULL, 'feedback', '2025-08-11 06:28:20.834', 10605, 2947, 94),
(NULL, 'products are moving well', '2025-08-11 09:02:50.142', 10605, 2948, 109),
(NULL, 'The product is still available but affected by lack of display.', '2025-08-11 10:59:20.560', 10605, 2949, 23),
(NULL, 'updated ', '2025-08-11 11:08:59.322', 10605, 2950, 23),
(NULL, 'The product movement is affected by lack of display ', '2025-08-11 11:57:01.003', 10605, 2951, 23),
(NULL, 'Vapes doing well in movement', '2025-08-11 12:06:03.975', 10605, 2952, 5),
(NULL, 'To placevan ordrr on 5dots cooling citrus and sweet', '2025-08-11 12:20:22.162', 10605, 2953, 5),
(NULL, 'they need b2c \nhe\'s nice custome', '2025-08-11 12:26:01.159', 10605, 2954, 124),
(NULL, 'wwll stocked.Need 10pcs of chizi mint', '2025-08-11 12:39:07.440', 10605, 2955, 5),
(NULL, 'They placed an order and requested for an exchange of the 3 dots to 5 dots\n', '2025-08-11 12:40:40.798', 10605, 2956, 23),
(NULL, 'To place an order by this week ', '2025-08-11 12:53:47.105', 10605, 2957, 6),
(NULL, 'need an activation girl', '2025-08-11 13:03:26.659', 10605, 2958, 5),
(NULL, 'like our product', '2025-08-11 13:10:37.714', 10605, 2959, 124),
(NULL, 'will make an order by tomorrow ', '2025-08-11 13:29:30.380', 10605, 2960, 16),
(NULL, 'placed an order', '2025-08-11 13:30:53.719', 10605, 2961, 23),
(NULL, 'They are still waiting for feedback from HQ then they will recieve our product.', '2025-08-11 13:36:53.836', 10605, 2962, 69),
(NULL, 'The attendant will give me feedback by next week Monday, I am trying to onboard this client.', '2025-08-11 13:37:47.677', 10605, 2963, 23),
(NULL, 'needs our product', '2025-08-11 13:39:03.170', 10605, 2964, 124),
(NULL, 'well stocked ', '2025-08-11 13:41:22.558', 10605, 2965, 6),
(NULL, 'They have our products and still pushing though it going very slow', '2025-08-11 14:00:36.397', 10605, 2966, 102),
(NULL, '*following up on Payments ', '2025-08-11 14:01:50.586', 10605, 2967, 7),
(NULL, 'Competitor velo,hart and goat', '2025-08-11 14:04:02.199', 10605, 2968, 5),
(NULL, 'Stock moving slowly ', '2025-08-11 14:06:04.659', 10605, 2969, 6),
(NULL, 'The progress is going very slow but still hoping they will make it ', '2025-08-11 14:16:58.573', 10605, 2970, 102),
(NULL, '*still have stock ', '2025-08-11 14:15:37.524', 10605, 2971, 7),
(NULL, 'to restock soon', '2025-08-11 14:19:08.577', 10605, 2972, 6),
(NULL, 'Awaiting 9000puffs to place order.', '2025-08-11 14:22:02.771', 10605, 2973, 57),
(NULL, 'nice sales from them', '2025-08-11 14:29:13.864', 10605, 2974, 124),
(NULL, 'placed an order for 50pouches', '2025-08-11 14:36:06.896', 10605, 2975, 5),
(NULL, 'I have shared their LPO for the Goldpouches ', '2025-08-11 14:56:48.163', 10605, 2976, 23),
(NULL, 'the product is slow moving die to lack of display ', '2025-08-11 15:04:02.683', 10605, 2977, 23),
(NULL, 'placed an order for 50pcs of pouchss', '2025-08-11 15:08:12.193', 10605, 2978, 5),
(NULL, 'ordered 10pcs 9000 puffs 5 pcs 3000 puffs', '2025-08-11 15:22:29.817', 10605, 2979, 5),
(NULL, '*3 PCs remaining to place order by Friday after making the payments ', '2025-08-11 15:39:37.473', 10605, 2980, 7),
(NULL, '*they will place an order next week,the movement is good ', '2025-08-11 15:57:54.946', 10605, 2981, 7),
(NULL, 'slow moving ', '2025-08-11 16:02:23.297', 10605, 2982, 20),
(NULL, 'slow movement on our vapes', '2025-08-11 16:08:40.605', 10605, 2983, 59),
(NULL, 'product is not moving at all. very small client patronage to this outlet. they make better sales on shisha. an incentive may be necessary to boost sales. ', '2025-08-11 16:24:10.561', 10605, 2984, 57),
(NULL, 'they will give an order at the end of the week.', '2025-08-11 16:29:09.574', 10605, 2985, 23),
(NULL, '*moving slowly \n', '2025-08-11 16:34:46.515', 10605, 2986, 7),
(NULL, '* they have 5 PCs remaining ', '2025-08-11 16:48:44.493', 10605, 2987, 7),
(NULL, 'order done', '2025-08-11 16:50:52.625', 10605, 2988, 20),
(NULL, 'they received their order for the Goldpouches ', '2025-08-11 16:50:56.261', 10605, 2989, 23),
(NULL, 'the outlet is stocked ', '2025-08-11 17:10:24.354', 10605, 2990, 20),
(NULL, 'they will give their order tomorrow ', '2025-08-11 17:16:49.963', 10605, 2991, 23),
(NULL, 'I’ll keep on checking on the stocks', '2025-08-11 18:04:42.627', 10605, 2992, 20),
(NULL, 'we willl order 3000 puffs', '2025-08-11 18:09:33.257', 10605, 2993, 20),
(NULL, 'our orders are system based waiting for one on Thursday ', '2025-08-11 18:31:24.871', 10605, 2994, 20),
(NULL, 'they said they will talk to their boss and call me. i left my contacts', '2025-08-11 18:31:40.696', 10605, 2995, 125),
(NULL, 'They said until it is finished all ', '2025-08-11 18:40:57.519', 10605, 2996, 69),
(NULL, 'ordered 10pcs 9000 puffs and 5pcs 3000 puffs', '2025-08-11 19:06:32.027', 10605, 2997, 5),
(NULL, 'they have receive today', '2025-08-11 19:12:52.358', 10605, 2998, 125),
(NULL, 'pr', '2025-08-12 10:15:57.733', 10605, 2999, 109),
(NULL, 'progressing on so well ', '2025-08-12 10:20:46.102', 10605, 3000, 109),
(NULL, 'progressing on so well', '2025-08-12 10:26:50.664', 10605, 3001, 109),
(NULL, 'well stocked on pouches', '2025-08-12 10:31:08.751', 10605, 3002, 23),
(NULL, 'well stocked', '2025-08-12 10:31:24.625', 10605, 3003, 5),
(NULL, 'updatef', '2025-08-12 10:32:18.241', 10605, 3004, 5),
(NULL, 'moving out so well', '2025-08-12 10:41:05.826', 10605, 3005, 109),
(NULL, 'movement is good\nengaged them on the media kit\nselling under the counter', '2025-08-12 10:43:27.381', 10605, 3006, 23),
(NULL, 'movement good,selling under the counter.Engaged and confirmed on mediackit', '2025-08-12 10:43:33.624', 10605, 3007, 5),
(NULL, 'updated ', '2025-08-12 10:47:01.084', 10605, 3008, 23),
(NULL, 'to place an ordrer on 5dots pouchea and  9000 puffs', '2025-08-12 11:25:58.489', 10605, 3009, 5),
(NULL, 'products are moving well', '2025-08-12 11:33:00.219', 10605, 3010, 109),
(NULL, 'They will place another order for the 5 dot Goldpouches ', '2025-08-12 11:33:12.121', 10605, 3011, 23),
(NULL, 'they sell only shisha', '2025-08-12 12:07:45.375', 10605, 3012, 124),
(NULL, 'well stocked ', '2025-08-12 12:15:39.840', 10605, 3013, 16),
(NULL, 'few pieces remaining ', '2025-08-12 12:25:46.734', 10605, 3014, 6),
(NULL, 'They are stocked on the available skus', '2025-08-12 12:59:15.783', 10605, 3015, 23),
(NULL, 'following up on low stocks', '2025-08-12 13:24:30.236', 10605, 3016, 20),
(NULL, 'have debts with Dantra hence can\'t order', '2025-08-12 13:31:49.049', 10605, 3017, 23),
(NULL, 'Yhe stock take is ending today so the order will be placed tomorrow ', '2025-08-12 13:33:02.782', 10605, 3018, 20),
(NULL, 'like ', '2025-08-12 13:51:17.574', 10605, 3019, 70),
(NULL, 'need to discuss further with other managers.. they\'ll get back to us', '2025-08-12 13:53:11.223', 10605, 3020, 124),
(NULL, '*they usually buy few pieces from distributor ', '2025-08-12 14:02:33.051', 10605, 3021, 7),
(NULL, 'will make another visit, ', '2025-08-12 14:08:11.414', 10605, 3022, 124),
(NULL, 'They have our products and still pushing it to the end users ', '2025-08-12 14:11:46.518', 10605, 3023, 102),
(NULL, 'They have a pending invoice that\'s why they don\'t have an irder', '2025-08-12 14:16:20.095', 10605, 3024, 23),
(NULL, 'made an order of both pauches and vapes ', '2025-08-12 14:22:45.979', 10605, 3025, 16),
(NULL, 'stocks moving well', '2025-08-12 14:26:43.061', 10605, 3026, 5),
(NULL, 'they need sample, but we\'ll discuss further soon.', '2025-08-12 14:28:04.941', 10605, 3027, 124),
(NULL, 'they place an orders of 9000puffs 10 pieces', '2025-08-12 14:28:36.875', 10605, 3028, 6),
(NULL, 'They have our products though the pushing is going very slow only one pics is sold up todate', '2025-08-12 14:43:13.843', 10605, 3029, 102),
(NULL, 'order done', '2025-08-12 14:45:55.751', 10605, 3030, 5),
(NULL, 'they have 92 pieces remaining..they will place an order soon', '2025-08-12 14:57:37.205', 10605, 3031, 6),
(NULL, 'placed an order ', '2025-08-12 15:00:59.032', 10605, 3032, 23),
(NULL, 'Activated on b2c customers recommend 9000 puffs', '2025-08-12 15:02:15.443', 10605, 3033, 5),
(NULL, 'well stocked ', '2025-08-12 15:20:45.230', 10605, 3034, 7),
(NULL, 'received their order for 5dots', '2025-08-12 15:27:58.723', 10605, 3035, 5),
(NULL, '*they still have stock ', '2025-08-12 15:34:18.466', 10605, 3036, 7),
(NULL, 'the owner will give me feedback on when to place the order ', '2025-08-12 15:43:33.443', 10605, 3037, 23),
(NULL, 'slow movement', '2025-08-12 15:57:40.081', 10605, 3038, 5),
(NULL, 'placed an order on pouches', '2025-08-12 16:07:45.624', 10605, 3039, 5),
(NULL, '*still have stock ', '2025-08-12 16:08:02.243', 10605, 3040, 7),
(NULL, 'system places the order every Monday ', '2025-08-12 16:15:00.443', 10605, 3041, 20),
(NULL, 'movement is good', '2025-08-12 16:16:51.221', 10605, 3042, 5),
(NULL, 'placed an order', '2025-08-12 16:30:47.486', 10605, 3043, 23),
(NULL, '*they haven\'t sold any piece since last week ', '2025-08-12 16:29:08.122', 10605, 3044, 7),
(NULL, 'They have placed an order of 9pcs for 3000puffs ', '2025-08-12 16:31:51.072', 10605, 3045, 28),
(NULL, 'well stocked', '2025-08-12 16:32:58.509', 10605, 3046, 5),
(NULL, 'Well stocked. Awaiting B2C payment. Will not order pouches this month due to competition from Velo.', '2025-08-12 16:51:03.548', 10605, 3047, 57),
(NULL, 'will order pouches next week', '2025-08-12 16:53:14.098', 10605, 3048, 5),
(NULL, 'order placed for pouches ', '2025-08-12 16:57:43.892', 10605, 3049, 20),
(NULL, 'just took 20 pcs today', '2025-08-12 17:06:25.419', 10605, 3050, 124),
(NULL, 'requesting for an exchange of Gold pouches with 3000puffs ', '2025-08-12 17:17:20.914', 10605, 3051, 28),
(NULL, 'Have not received their order which they placed last week. ', '2025-08-12 17:48:07.823', 10605, 3052, 57),
(NULL, 'They are well stocked for now ', '2025-08-12 17:51:44.508', 10605, 3053, 28),
(NULL, 'still stocked ', '2025-08-12 17:54:28.318', 10605, 3054, 20),
(NULL, 'they said they will call me', '2025-08-12 17:59:11.366', 10605, 3055, 125),
(NULL, 'we are not getting any orders till we do the replacement ', '2025-08-12 18:16:34.677', 10605, 3056, 20),
(NULL, 'They said i come tomorrlw to meet the boss and talk to him', '2025-08-12 19:38:17.239', 10605, 3057, 69),
(NULL, 'products are moving well', '2025-08-13 09:31:52.471', 10605, 3058, 109),
(NULL, 'progressing on so well', '2025-08-13 10:07:49.457', 10605, 3059, 109),
(NULL, 'need to discuss further with owner', '2025-08-13 12:14:43.656', 10605, 3060, 124),
(NULL, 'need to discuss with owners', '2025-08-13 12:44:06.697', 10605, 3061, 124),
(NULL, 'manager was not in so I left my number.', '2025-08-13 12:46:00.386', 10605, 3062, 124),
(NULL, 'They really like our products and kindly need 20 pcs', '2025-08-13 13:08:25.212', 10605, 3063, 102),
(NULL, 'progressing well', '2025-08-13 14:44:13.540', 10605, 3064, 109),
(NULL, 'progressing well', '2025-08-13 14:48:27.232', 10605, 3065, 109),
(NULL, 'Manager not available ', '2025-08-13 14:56:48.349', 10605, 3066, 16),
(NULL, 'manager wasn\'t available ', '2025-08-13 15:03:41.577', 10605, 3067, 16),
(NULL, 'uplifted 10 pieces to kilgoris Longorian', '2025-08-13 15:23:29.072', 10605, 3068, 6),
(NULL, 'they have not received their order which I placed', '2025-08-13 15:34:59.241', 10605, 3069, 6),
(NULL, 'Thinking about taking our product ', '2025-08-13 15:39:34.631', 10605, 3070, 69),
(NULL, 'BAC has requested me to revisit tomorrow for stock transfer to Naivas Oasis. Placed order for pouches. Order sheet to be provided tomorrow. ', '2025-08-13 15:40:49.945', 10605, 3071, 57),
(NULL, 'we arranged products on display', '2025-08-13 16:25:47.979', 10605, 3072, 125),
(NULL, 'Identifying the cause blocking this outlet from receiving stocks. ', '2025-08-13 16:37:47.475', 10605, 3073, 57),
(NULL, 'They have made an order of 10pcs for 3000puffs ', '2025-08-13 16:52:05.883', 10605, 3074, 28),
(NULL, '*still have 5pcs remaining \n*they don\'t want to restock pouches ', '2025-08-13 16:53:01.816', 10605, 3075, 7),
(NULL, '*they still have the 4pcs they haven\'t sold yet ', '2025-08-13 17:08:14.648', 10605, 3076, 7),
(NULL, '*12 PCs in stock ', '2025-08-13 17:30:16.325', 10605, 3077, 7),
(NULL, 'promised to stock this weekend ', '2025-08-13 17:50:21.516', 10605, 3078, 6),
(NULL, 'They are well stocked for now ', '2025-08-13 17:50:58.097', 10605, 3079, 28),
(NULL, 'placed an order for 10 PCs of vapes', '2025-08-13 18:29:03.015', 10605, 3080, 23),
(NULL, 'They have a pending debt', '2025-08-13 18:36:45.672', 10605, 3081, 23),
(NULL, 'waiting for cheque to place an order', '2025-08-13 18:36:56.768', 10605, 3082, 5),
(NULL, 'gotten an order for 10pcs', '2025-08-13 18:51:42.555', 10605, 3083, 5),
(NULL, 'Tomorrow i will deliver ', '2025-08-13 18:54:26.150', 10605, 3084, 69),
(NULL, 'left the pouches codes for orders', '2025-08-13 19:18:30.529', 10605, 3085, 5),
(NULL, 'products moving on so well', '2025-08-14 10:07:28.261', 10605, 3086, 109),
(NULL, 'moving out so well ', '2025-08-14 10:14:05.490', 10605, 3087, 109),
(NULL, 'well stocked', '2025-08-14 10:53:43.272', 10605, 3088, 109),
(NULL, 'received and ready for sale ', '2025-08-14 11:22:04.207', 10605, 3089, 69),
(NULL, 'I will get feedback on their payment @4 pm since the accountant is not in.', '2025-08-14 11:30:13.002', 10605, 3090, 23),
(NULL, 'organising stock transfer', '2025-08-14 11:44:10.017', 10605, 3091, 57),
(NULL, 'I got the contact for their procurement to follow up on onboardinh them', '2025-08-14 11:44:25.599', 10605, 3092, 23),
(NULL, 'well stocked movement is good', '2025-08-14 12:04:17.848', 10605, 3093, 5),
(NULL, 'I got the managers contact to onboard them.', '2025-08-14 12:15:03.552', 10605, 3094, 23),
(NULL, 'only received pouch order', '2025-08-14 12:16:52.654', 10605, 3095, 57),
(NULL, '*still have stock ', '2025-08-14 12:33:47.743', 10605, 3096, 7),
(NULL, 'they have our products and still pushing to the market ', '2025-08-14 12:42:34.258', 10605, 3097, 102),
(NULL, ' still have enough stock for now ', '2025-08-14 12:40:36.349', 10605, 3098, 7),
(NULL, 'I will get their order for pouches tomorrow ', '2025-08-14 13:04:01.309', 10605, 3099, 23),
(NULL, 'to restock  Stock soon', '2025-08-14 13:09:28.396', 10605, 3100, 6),
(NULL, '*waiting for their order to be delivered by dantra ', '2025-08-14 13:09:58.057', 10605, 3101, 7),
(NULL, 'pushing for a payment with mariete them place another order.', '2025-08-14 13:23:16.839', 10605, 3102, 23),
(NULL, 'waiting for am order', '2025-08-14 13:24:59.530', 10605, 3103, 5),
(NULL, 'They have placed an order of 1000 pieces for 3000puffs ', '2025-08-14 13:28:11.033', 10605, 3104, 28),
(NULL, 'They\'re well stocked for now ', '2025-08-14 13:34:19.331', 10605, 3105, 28),
(NULL, 'doing a replacement and getting an order', '2025-08-14 13:34:49.306', 10605, 3106, 5),
(NULL, '*they still have 7 PCs in stock ', '2025-08-14 13:41:46.823', 10605, 3107, 7),
(NULL, '*they want to place an order but we don\'t have the flavours ', '2025-08-14 13:48:55.594', 10605, 3108, 7),
(NULL, 'Manager not available ', '2025-08-14 14:16:17.724', 10605, 3109, 16),
(NULL, 'they are well stocked on all skus', '2025-08-14 14:20:12.518', 10605, 3110, 23),
(NULL, 'they deal with other kind of vapes', '2025-08-14 14:22:20.744', 10605, 3111, 124),
(NULL, 'pouches are selling well', '2025-08-14 14:24:00.774', 10605, 3112, 20),
(NULL, 'new outlet givsn them a display', '2025-08-14 14:24:38.290', 10605, 3113, 5),
(NULL, 'pushing for an order of 3000puffs ', '2025-08-14 14:51:02.203', 10605, 3114, 28),
(NULL, 'Will order 3000 puffs and pouches', '2025-08-14 15:03:04.921', 10605, 3115, 5),
(NULL, 'we will resolve the issue of displaying in BAT display on Monday ', '2025-08-14 15:07:32.719', 10605, 3116, 23),
(NULL, '*no product due to issues of payment ', '2025-08-14 15:11:01.154', 10605, 3117, 7),
(NULL, 'To place an order of 3000puffs ', '2025-08-14 15:13:08.925', 10605, 3118, 28),
(NULL, 'To place an order for 3000puffs ', '2025-08-14 15:15:12.389', 10605, 3119, 28),
(NULL, 'to order 3000 puffs', '2025-08-14 15:16:02.091', 10605, 3120, 5),
(NULL, 'I will get an order from their supervisor ', '2025-08-14 15:22:45.426', 10605, 3121, 23),
(NULL, 'they are in construction to expand their business they said they will call me ', '2025-08-14 15:25:44.448', 10605, 3122, 125),
(NULL, 'updated ', '2025-08-14 15:32:11.912', 10605, 3123, 23),
(NULL, 'customer need sometime to think about it.', '2025-08-14 15:35:44.331', 10605, 3124, 124),
(NULL, 'waiting for the sticking of the 9000puffs vapes', '2025-08-14 15:56:19.147', 10605, 3125, 59),
(NULL, 'already considered other brands but will order next week', '2025-08-14 16:02:04.565', 10605, 3126, 5),
(NULL, 'orders are not weekly via the system ', '2025-08-14 16:02:33.850', 10605, 3127, 20),
(NULL, 'well stocked', '2025-08-14 16:10:19.178', 10605, 3128, 5),
(NULL, 'Requesting timelines for stock return, they want to place an order for 100pcs vapes', '2025-08-14 16:12:55.457', 10605, 3129, 57),
(NULL, 'received some stock on vapes', '2025-08-14 16:15:46.075', 10605, 3130, 59),
(NULL, 'they are making payments so we place another order', '2025-08-14 16:19:45.457', 10605, 3131, 23),
(NULL, 'the market is currently slow', '2025-08-14 16:24:27.351', 10605, 3132, 59),
(NULL, 'still have Stock ', '2025-08-14 16:27:18.433', 10605, 3133, 6),
(NULL, 'still have ', '2025-08-14 16:28:27.161', 10605, 3134, 6),
(NULL, 'Met Ishmael former employee from Kentwood asked me to meet the owner tomorrow at 9:30 am to try onboard the vapes in the outlet', '2025-08-14 16:30:31.767', 10605, 3135, 23),
(NULL, '6 pieces remaining placing an order soon', '2025-08-14 16:39:51.737', 10605, 3136, 6),
(NULL, 'collected one display ', '2025-08-14 16:42:44.604', 10605, 3137, 23),
(NULL, 'velo has take over our pouches', '2025-08-14 16:44:05.407', 10605, 3138, 59),
(NULL, 'asking if the pouches can be changed to vapes since vapes are moving put pouches are not', '2025-08-14 16:52:07.571', 10605, 3139, 59),
(NULL, '6 pieces remaining making a reorder soon', '2025-08-14 16:56:42.611', 10605, 3140, 6),
(NULL, 'was asked to visit kikies to do listing but didn\'t meet the procurement person. asked to visit tomorrow.', '2025-08-14 16:58:20.938', 10605, 3141, 23),
(NULL, 'Still waiting for approval.outlet not ready to stock', '2025-08-14 17:19:13.672', 10605, 3142, 5),
(NULL, 'slow movement of the product', '2025-08-14 17:22:25.877', 10605, 3143, 6),
(NULL, 'their orders come from Shell Ndenderu. I have to plan to do a visit in the outlet ', '2025-08-14 17:22:30.479', 10605, 3144, 23),
(NULL, 'to order pouches only 2 pcs left', '2025-08-14 17:27:10.898', 10605, 3145, 5),
(NULL, 'willing to take on credit', '2025-08-14 17:31:43.392', 10605, 3146, 124),
(NULL, 'need more 9000puffs', '2025-08-14 17:37:50.369', 10605, 3147, 59),
(NULL, 'met the new stock controller and we will be checking stock levels every Wednesday ', '2025-08-14 18:01:07.935', 10605, 3148, 23),
(NULL, 'we only received minty snow ', '2025-08-14 18:06:32.224', 10605, 3149, 20),
(NULL, 'Will stock by next week ', '2025-08-14 18:26:01.239', 10605, 3150, 16),
(NULL, '*will place an order next week ', '2025-08-14 18:25:27.709', 10605, 3151, 7),
(NULL, 'manager said will order once ready financialy', '2025-08-14 19:12:18.711', 10605, 3152, 16),
(NULL, 'asked to meet the owner at 6 pm', '2025-08-15 11:10:37.068', 10605, 3153, 23),
(NULL, 'the procurement manager is not in yet', '2025-08-15 11:21:01.030', 10605, 3154, 23),
(NULL, 'Is yet to get approval to place an order for us to go ahead with the media kit', '2025-08-15 11:42:00.183', 10605, 3155, 23),
(NULL, '*they still have enough stock ', '2025-08-15 12:21:57.454', 10605, 3156, 7),
(NULL, '64 pieces remaining placing an order before end month', '2025-08-15 12:36:39.326', 10605, 3157, 6),
(NULL, 'They have sold 2 PCs in the last one month. they need an activation girl ', '2025-08-15 12:36:50.744', 10605, 3158, 23),
(NULL, 'slow movement', '2025-08-15 12:44:18.902', 10605, 3159, 5),
(NULL, '*still have stock ', '2025-08-15 12:42:46.661', 10605, 3160, 7),
(NULL, 'Agreed with Tanya to place an order when we have all stocks', '2025-08-15 12:53:03.411', 10605, 3161, 23),
(NULL, '*they will place order on Monday ', '2025-08-15 12:57:13.537', 10605, 3162, 7),
(NULL, 'stoçk available ', '2025-08-15 13:06:13.449', 10605, 3163, 16),
(NULL, 'The 9000 puffs is almost out of stock', '2025-08-15 13:12:31.305', 10605, 3164, 23),
(NULL, 'left a proposed order for pouches', '2025-08-15 13:17:59.969', 10605, 3165, 5),
(NULL, 'Client wants their B2C payment. ', '2025-08-15 13:20:52.685', 10605, 3166, 57),
(NULL, 'products still available ', '2025-08-15 13:27:29.417', 10605, 3167, 16),
(NULL, 'slow progress ', '2025-08-15 13:30:28.838', 10605, 3168, 109),
(NULL, 'they will be issued a demand letter for the pending payment ', '2025-08-15 13:48:28.941', 10605, 3169, 23),
(NULL, 'updated ', '2025-08-15 13:49:59.991', 10605, 3170, 23),
(NULL, 'almost out of stock ', '2025-08-15 13:54:36.906', 10605, 3171, 16),
(NULL, 'slow moving will placecorder nextvwerk', '2025-08-15 14:00:10.400', 10605, 3172, 5),
(NULL, 'display yet to be completed ', '2025-08-15 14:03:35.648', 10605, 3173, 16),
(NULL, 'slow movement', '2025-08-15 14:04:59.523', 10605, 3174, 5),
(NULL, 'out of stock for woosh to place order today ', '2025-08-15 14:04:22.532', 10605, 3175, 7),
(NULL, 'still waiting for there delivery ', '2025-08-15 14:13:35.513', 10605, 3176, 16),
(NULL, 'placed an order for vapes and pouches ', '2025-08-15 14:26:23.028', 10605, 3177, 23),
(NULL, 'will add pouches 5dits cooling and mixedberry', '2025-08-15 14:31:23.174', 10605, 3178, 5),
(NULL, 'movement is good', '2025-08-15 14:44:52.148', 10605, 3179, 5),
(NULL, '*18pcs 9000 puffs and 16 PCs 3000 puffs', '2025-08-15 14:44:30.066', 10605, 3180, 7),
(NULL, 'Still well stocked on all SKUs', '2025-08-15 14:47:17.802', 10605, 3181, 57),
(NULL, 'they only sell liquors', '2025-08-15 14:47:55.084', 10605, 3182, 124),
(NULL, 'products are moving well', '2025-08-15 14:58:48.614', 10605, 3183, 109),
(NULL, 'to get an approval from the manager to place this order ', '2025-08-15 15:08:49.193', 10605, 3184, 23),
(NULL, 'will order cooling mint after seeing movement', '2025-08-15 15:16:38.154', 10605, 3185, 5),
(NULL, 'The manager saw the product but they said it’s not going at their side they are only sailing normal cigarettes ', '2025-08-15 15:17:36.192', 10605, 3186, 69),
(NULL, 'the manager was not in but I got his number and have advised me to come some other day', '2025-08-15 15:22:21.675', 10605, 3187, 124),
(NULL, 'they received their order today ', '2025-08-15 15:25:45.236', 10605, 3188, 102),
(NULL, 'proposed order', '2025-08-15 15:33:22.294', 10605, 3189, 5),
(NULL, 'from their last order they have managed to sell one piece for the vape', '2025-08-15 15:44:57.787', 10605, 3190, 23),
(NULL, 'updated ', '2025-08-15 15:46:15.194', 10605, 3191, 23),
(NULL, 'client is unresponsive to returning display. Will not place order until 9000 puffs are back in stock. ', '2025-08-15 15:50:10.605', 10605, 3192, 57),
(NULL, 'need sample for taste', '2025-08-15 15:59:15.526', 10605, 3193, 124),
(NULL, 'order placed', '2025-08-15 16:08:41.910', 10605, 3194, 5);
INSERT INTO `FeedbackReport` (`reportId`, `comment`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(NULL, 'placdf order', '2025-08-15 16:09:37.122', 10605, 3195, 5),
(NULL, 'They have only sold 2 PCs for the Goldpouch since my last visit.', '2025-08-15 16:11:42.766', 10605, 3196, 23),
(NULL, 'slow movement since it cant be displayed', '2025-08-15 16:14:37.198', 10605, 3197, 5),
(NULL, 'the owner like our products ', '2025-08-15 16:20:12.214', 10605, 3198, 70),
(NULL, 'met KYMs who said I forward him the Invoice to follow up with Teddy and said outlets to place orders on their own.', '2025-08-15 16:33:03.194', 10605, 3199, 23),
(NULL, 'Client is stocked with dawa,Chily Lemon Soda, Caramel Hazelnut and Fresh Lychee. The flavours are performing poorly. Awaiting 9000 puffs to restock and make exchanges. ', '2025-08-15 16:33:35.140', 10605, 3200, 57),
(NULL, 'They received their order ', '2025-08-15 16:46:58.617', 10605, 3201, 23),
(NULL, 'to place their order after we get the 9000 puffs in stock', '2025-08-15 16:47:11.102', 10605, 3202, 7),
(NULL, 'not good ', '2025-08-15 16:50:17.228', 10605, 3203, 70),
(NULL, 'customers have been requesting 9000 puffs for over a month ', '2025-08-15 17:10:16.159', 10605, 3204, 57),
(NULL, 'They will have the 3 dots exchanged to 5 dot and a display picked to be returned to the office.', '2025-08-15 17:11:52.133', 10605, 3205, 23),
(NULL, 'movement not bad', '2025-08-15 17:15:37.159', 10605, 3206, 2),
(NULL, 'They will order once Hart stocks reduce', '2025-08-15 17:17:22.146', 10605, 3207, 2),
(NULL, 'They are well stocked for now ', '2025-08-15 17:24:53.745', 10605, 3208, 28),
(NULL, 'Gold puff doing well.', '2025-08-15 17:28:50.843', 10605, 3209, 2),
(NULL, 'Movement okay', '2025-08-15 17:48:57.307', 10605, 3210, 2),
(NULL, 'still well stocked ', '2025-08-15 17:52:39.866', 10605, 3211, 28),
(NULL, 'Slow movement', '2025-08-15 17:55:45.690', 10605, 3212, 2),
(NULL, 'Still well stocked ', '2025-08-15 18:18:56.467', 10605, 3213, 28),
(NULL, 'the manager was not around', '2025-08-15 19:46:40.978', 10605, 3214, 125),
(NULL, 'will pay by first week 9f September ', '2025-08-16 11:16:08.069', 10605, 3215, 57),
(NULL, 'slow movement', '2025-08-16 11:22:41.026', 10605, 3216, 5),
(NULL, 'good', '2025-08-16 11:23:46.104', 10605, 3217, 5),
(NULL, 'good', '2025-08-16 11:25:00.252', 10605, 3218, 5),
(NULL, 'Well stocked ', '2025-08-16 12:28:04.859', 10605, 3219, 57),
(NULL, 'Stock is moving swifty but there are many faulty ', '2025-08-16 12:28:52.914', 10605, 3220, 6),
(NULL, 'need 9000 puffs', '2025-08-16 12:34:14.835', 10605, 3221, 5),
(NULL, 'slow movement goat doing better', '2025-08-16 12:44:04.973', 10605, 3222, 5),
(NULL, 'progressing on so well ', '2025-08-16 12:59:11.905', 10605, 3223, 109),
(NULL, 'gotten order', '2025-08-16 13:00:25.307', 10605, 3224, 5),
(NULL, 'They asked I remove the display since we don\'t have an approval or memo to mount ', '2025-08-16 13:17:17.968', 10605, 3225, 23),
(NULL, 'movement is slow', '2025-08-16 13:45:59.861', 10605, 3226, 109),
(NULL, 'slow', '2025-08-16 13:49:46.716', 10605, 3227, 5),
(NULL, 'vapes are moving well but g.p are moving out slowly', '2025-08-16 14:03:20.421', 10605, 3228, 109),
(NULL, 'they are well stocked on all skus ', '2025-08-16 14:06:57.737', 10605, 3229, 23),
(NULL, 'we will place an order on Monday ', '2025-08-16 14:31:45.285', 10605, 3230, 23),
(NULL, 'vapes moving on so well\npouches are constant', '2025-08-16 14:32:25.724', 10605, 3231, 109),
(NULL, 'progressing on so well ', '2025-08-16 14:48:31.270', 10605, 3232, 109),
(NULL, '*they still have the 7pcs', '2025-08-16 14:55:35.278', 10605, 3233, 7),
(NULL, 'progressing on so well ', '2025-08-16 15:00:07.167', 10605, 3234, 109),
(NULL, 'few pieces remaining ', '2025-08-16 15:11:04.575', 10605, 3235, 6),
(NULL, 'Still need time ', '2025-08-16 15:15:16.727', 10605, 3236, 124),
(NULL, 'they needed an order for minty snow and Fresh Lychee but we don\'t have them ', '2025-08-16 15:57:12.675', 10605, 3237, 23),
(NULL, 'updated ', '2025-08-16 16:17:14.374', 10605, 3238, 23),
(NULL, '*the movement is slow ', '2025-08-16 16:27:16.988', 10605, 3239, 7),
(NULL, 'They expect their uplift from their HQ on Monday ', '2025-08-16 16:29:25.422', 10605, 3240, 23),
(NULL, '*they still have stock ', '2025-08-16 16:56:34.095', 10605, 3241, 7),
(NULL, 'they only sell foods and soft drinks', '2025-08-16 17:25:45.127', 10605, 3242, 124),
(NULL, 'received 5 faulty vapes to be exchanged on Monday ', '2025-08-16 17:34:05.779', 10605, 3243, 23),
(NULL, 'placed an order for the Goldpouches ', '2025-08-16 17:54:20.423', 10605, 3244, 23),
(NULL, '56 pieces remaining ', '2025-08-16 18:41:20.717', 10605, 3245, 6),
(NULL, 'still need time, haven\'t confrim with the boss', '2025-08-16 18:46:15.604', 10605, 3246, 124),
(NULL, 'active sales', '2025-08-16 20:18:34.937', 10605, 3247, 16),
(NULL, 'well stocked', '2025-08-18 09:46:24.077', 10605, 3248, 109),
(NULL, 'progressing on so well', '2025-08-18 11:03:11.106', 10605, 3249, 109),
(NULL, 'progressing on so well ', '2025-08-18 11:19:42.168', 10605, 3250, 109),
(NULL, 'To restock ', '2025-08-18 12:11:10.853', 10605, 3251, 6),
(NULL, 'progressing well ', '2025-08-18 12:43:26.185', 10605, 3252, 109),
(NULL, 'progressing well ', '2025-08-18 12:45:14.650', 10605, 3253, 109),
(NULL, 'progressing on so well ', '2025-08-18 12:48:39.139', 10605, 3254, 109),
(NULL, 'Staff are pushing and making good sales. Requesting T-shirt for Gold pouch, B2C payment and display for pouches', '2025-08-18 13:19:03.825', 10605, 3255, 57),
(NULL, 'Making a proposed order with stock controller to prepare them for stock arrival ', '2025-08-18 13:45:08.353', 10605, 3256, 57),
(NULL, 'velo selling more than pouches ', '2025-08-18 14:02:01.448', 10605, 3257, 7),
(NULL, '*slow movement ', '2025-08-18 14:21:38.383', 10605, 3258, 7),
(NULL, 'nice sales', '2025-08-18 14:27:12.431', 10605, 3259, 70),
(NULL, 'on the conversation stage not yet meeting the manager ', '2025-08-18 14:58:58.569', 10605, 3260, 102),
(NULL, 'Wants to order 9000 puffs ', '2025-08-18 15:01:59.010', 10605, 3261, 57),
(NULL, 'They don\'t sell any kind of cigarate ', '2025-08-18 15:15:50.326', 10605, 3262, 124),
(NULL, '*they have sold just one piece since my previous visit ', '2025-08-18 15:18:46.859', 10605, 3263, 7),
(NULL, 'manager not in yet no difitive answer ', '2025-08-18 15:23:44.534', 10605, 3264, 124),
(NULL, 'don\'t sell any kind of cigarate', '2025-08-18 15:35:27.780', 10605, 3265, 124),
(NULL, 'pushing for an order ', '2025-08-18 15:40:23.943', 10605, 3266, 6),
(NULL, 'like', '2025-08-18 15:44:40.771', 10605, 3267, 102),
(NULL, 'need to confrim with owner', '2025-08-18 15:44:39.006', 10605, 3268, 124),
(NULL, 'not bad in sales', '2025-08-18 15:48:53.245', 10605, 3269, 102),
(NULL, 'requires exchange to 9000puffs ', '2025-08-18 15:52:43.896', 10605, 3270, 57),
(NULL, 'They have move they have remain 9 ', '2025-08-18 16:13:48.392', 10605, 3271, 69),
(NULL, 'need to confrim with owner', '2025-08-18 16:20:16.150', 10605, 3272, 124),
(NULL, 'need to confrim with owner', '2025-08-18 16:21:50.887', 10605, 3273, 124),
(NULL, '*they have stocks still', '2025-08-18 16:26:54.799', 10605, 3274, 7),
(NULL, 'still have stock ', '2025-08-18 16:36:33.627', 10605, 3275, 7),
(NULL, 'To place an order soon ', '2025-08-18 17:48:39.637', 10605, 3276, 28),
(NULL, 'slow movement of the products ', '2025-08-19 08:23:16.676', 10605, 3277, 109),
(NULL, 'vapes moving on so well \npouches are still constant ', '2025-08-19 09:51:59.382', 10605, 3278, 109),
(NULL, 'moving on so well ', '2025-08-19 10:37:30.741', 10605, 3279, 109),
(NULL, 'progressing on so well ', '2025-08-19 10:44:02.829', 10605, 3280, 109),
(NULL, 'no liquor', '2025-08-19 10:51:57.759', 10605, 3281, 5),
(NULL, 'no liquor', '2025-08-19 10:53:18.715', 10605, 3282, 5),
(NULL, 'placed an order', '2025-08-19 10:58:42.049', 10605, 3283, 23),
(NULL, 'picked slow moving 6mgs and did an order', '2025-08-19 11:06:37.653', 10605, 3284, 5),
(NULL, 'Mounting 2nd display for show casing pouches', '2025-08-19 11:38:14.401', 10605, 3285, 57),
(NULL, 'well stocked', '2025-08-19 11:43:25.484', 10605, 3286, 5),
(NULL, 'reorder 5 pieces', '2025-08-19 11:44:20.957', 10605, 3287, 6),
(NULL, 'Mounting Display ', '2025-08-19 11:45:53.186', 10605, 3288, 57),
(NULL, 'made a reorder of 5 pieces', '2025-08-19 12:02:48.249', 10605, 3289, 6),
(NULL, 'cheque collection ', '2025-08-19 12:08:23.106', 10605, 3290, 57),
(NULL, '*placed an order of 16 pcs', '2025-08-19 12:06:42.513', 10605, 3291, 7),
(NULL, 'placed order', '2025-08-19 12:16:10.332', 10605, 3292, 57),
(NULL, 'stock holding is enough ', '2025-08-19 12:18:24.523', 10605, 3293, 20),
(NULL, 'To place order this week', '2025-08-19 12:19:42.560', 10605, 3294, 57),
(NULL, '29 pcs remaing making a reorder by friday', '2025-08-19 12:26:28.843', 10605, 3295, 6),
(NULL, '*they don\'t stock many pieces ', '2025-08-19 12:25:40.316', 10605, 3296, 7),
(NULL, 'made a new order for vape from their Nairobi outlet', '2025-08-19 12:28:38.494', 10605, 3297, 59),
(NULL, 'they will get approval from management when to place an order by the end of the week. I also requested a warning sticker for their display ', '2025-08-19 12:37:12.235', 10605, 3298, 23),
(NULL, '29 pieces remaining to make a reorder of 400 pieces 3000puffs by friday', '2025-08-19 12:38:53.317', 10605, 3299, 6),
(NULL, 'slow moving ', '2025-08-19 12:47:16.241', 10605, 3300, 20),
(NULL, 'Will order cooling mint and mixedberry 5 dots which are fast moving..And the other flavours of 9000 puffs because thry only have 3 chilly dawa lychee.', '2025-08-19 12:51:17.041', 10605, 3301, 5),
(NULL, '*they still have the 2 PCs remaining ', '2025-08-19 12:53:27.660', 10605, 3302, 7),
(NULL, 'slow movement on both vapes and pouches ', '2025-08-19 13:02:26.854', 10605, 3303, 59),
(NULL, 'slow movement ', '2025-08-19 13:08:25.041', 10605, 3304, 59),
(NULL, '*they still have 10 PCs in stock ', '2025-08-19 13:06:21.176', 10605, 3305, 7),
(NULL, 'well stocked with vapes', '2025-08-19 13:10:37.461', 10605, 3306, 28),
(NULL, 'They have promised to place order for vapes when the products reduced to 2', '2025-08-19 13:18:34.874', 10605, 3307, 20),
(NULL, 'To place an order for vapes and pouches ', '2025-08-19 13:26:41.113', 10605, 3308, 28),
(NULL, 'To place an order of vapes next week ', '2025-08-19 13:38:27.529', 10605, 3309, 28),
(NULL, 'our competitor is hart and its moving not fast moving but smoothly than our vapes', '2025-08-19 13:39:45.893', 10605, 3310, 59),
(NULL, 'She’s going to consult with the manager and give us an order I have proposed the order for them', '2025-08-19 13:40:28.052', 10605, 3311, 20),
(NULL, 'pouches they only have velo not will to stock our pouches ', '2025-08-19 13:52:22.331', 10605, 3312, 59),
(NULL, 'exchange to be done for 3000 to 9000 puffs', '2025-08-19 14:07:46.415', 10605, 3313, 20),
(NULL, 'They are out of stock on strawberry and mixedberry 5dots to place an order for vapes 9000 puffs too after codes are unblocked.', '2025-08-19 14:15:08.778', 10605, 3314, 5),
(NULL, 'owner not in. so I couldn\'t get a hold of him I\'ll to try again', '2025-08-19 14:22:57.612', 10605, 3315, 124),
(NULL, 'well stocked with both vapes and pouches ', '2025-08-19 14:25:29.503', 10605, 3316, 28),
(NULL, '*they still have enough stocks\n*139pcs 3000 puffs and 110 PCs 900puffs', '2025-08-19 14:24:09.397', 10605, 3317, 7),
(NULL, 'antil the owner come', '2025-08-19 14:31:18.277', 10605, 3318, 70),
(NULL, 'They don\'t Display fur to county government harassments. I requested the office to exchange 1 vape dawa cocktail which box has water damage.', '2025-08-19 14:34:18.112', 10605, 3319, 23),
(NULL, 'Manager says they will think about it and get back to me', '2025-08-19 14:37:50.981', 10605, 3320, 124),
(NULL, 'Visiting but not yet meeting the manager he will be around tomorrow ', '2025-08-19 14:41:58.918', 10605, 3321, 102),
(NULL, 'owner is willing to let me sell here directly.', '2025-08-19 14:46:13.751', 10605, 3322, 124),
(NULL, 'placed an order ', '2025-08-19 14:48:43.850', 10605, 3323, 10),
(NULL, 'I will back at night ', '2025-08-19 14:54:16.830', 10605, 3324, 70),
(NULL, 'test', '2025-08-19 14:55:08.928', 10605, 3325, 94),
(NULL, 'They have make an order for vapes and pouches today ', '2025-08-19 14:57:06.916', 10605, 3326, 28),
(NULL, 'velo here is currently out of stock.Competator is sky and Gogo', '2025-08-19 14:57:40.376', 10605, 3327, 59),
(NULL, 'manager needs time to think about it..gave out his contact info for further communication.', '2025-08-19 15:01:28.789', 10605, 3328, 124),
(NULL, 'placed an order on 9k puffs ', '2025-08-19 15:04:42.577', 10605, 3329, 10),
(NULL, 'They have placed an order for vapes and pouches ', '2025-08-19 15:11:40.905', 10605, 3330, 28),
(NULL, 'their stocks haven\'t arrived yet .', '2025-08-19 15:17:01.453', 10605, 3331, 10),
(NULL, 'They need an exchange of the 9000 puffs with the new fast moving flavors\n', '2025-08-19 15:38:37.417', 10605, 3332, 23),
(NULL, 'we are on the prior stage of the conversation and the manager really like and appreciate our products and showing interest on it', '2025-08-19 15:43:01.883', 10605, 3333, 102),
(NULL, 'they ordered 10 PCs of 9k puffs ', '2025-08-19 15:51:36.302', 10605, 3334, 10),
(NULL, 'no comment ', '2025-08-19 15:54:03.394', 10605, 3335, 71),
(NULL, 'Spoke to the manager who said he will speak to the owner. Waited only to be told manager has left. no conclusive feedback on stocking the products', '2025-08-19 15:54:54.746', 10605, 3336, 57),
(NULL, 'still continue to push', '2025-08-19 16:05:40.771', 10605, 3337, 71),
(NULL, 'They have placed an order', '2025-08-19 16:05:50.218', 10605, 3338, 23),
(NULL, 'Order placed to Dantra 3000 puffs', '2025-08-19 16:06:12.551', 10605, 3339, 20),
(NULL, 'they have placed an order for 10 PCs of vapes, 9000 puffs.', '2025-08-19 16:06:13.668', 10605, 3340, 23),
(NULL, 'expecting to make new order and make more sales from end this month as the british army will be coming in', '2025-08-19 16:06:22.602', 10605, 3341, 59),
(NULL, 'They dont have any 9000 puffs and 3000 puffs they only have 3flavours  theyll make an order on whats not available.\npouches they are well stocked\n', '2025-08-19 16:11:16.093', 10605, 3342, 5),
(NULL, '*to place order after making payments,the supervisor will resume on Friday ', '2025-08-19 16:11:04.995', 10605, 3343, 7),
(NULL, 'pushing for an of vapes', '2025-08-19 16:13:14.727', 10605, 3344, 28),
(NULL, 'don’t sell cigarettes ', '2025-08-19 16:15:12.364', 10605, 3345, 71),
(NULL, '23 pieces remaining..but the made a reorder date 17th', '2025-08-19 16:15:56.482', 10605, 3346, 6),
(NULL, '*to place an order after making payments the supervisor will resume on Friday ', '2025-08-19 16:28:23.588', 10605, 3347, 7),
(NULL, 'They have two displays one fr vapes the other for pouches.requested dor a sticker for 3000 puffs.Slow moving on 3000 puffs no single product sold', '2025-08-19 16:32:15.440', 10605, 3348, 5),
(NULL, '*they have sold 4pcs 3000 puffs and 2pcs 9000 puffs since my last visit ', '2025-08-19 16:40:57.974', 10605, 3349, 7),
(NULL, 'They have our products and already sold out 2 pcs', '2025-08-19 16:50:23.693', 10605, 3350, 102),
(NULL, 'well stocked for now ', '2025-08-19 17:04:12.606', 10605, 3351, 28),
(NULL, 'placed an order for 10 PCs of vapes', '2025-08-19 17:13:49.717', 10605, 3352, 23),
(NULL, 'exchange of 9000 puffs with 3000 puffs', '2025-08-19 17:26:12.048', 10605, 3353, 20),
(NULL, '*they will place an order next week ', '2025-08-19 17:27:24.585', 10605, 3354, 7),
(NULL, 'progressing on so well ', '2025-08-19 17:33:11.594', 10605, 3355, 109),
(NULL, 'placed an order ', '2025-08-19 17:33:27.687', 10605, 3356, 10),
(NULL, '*they have sold 2pcs woosh since my last visit ', '2025-08-19 17:43:54.098', 10605, 3357, 7),
(NULL, 'we will do exchange for 3000puffs', '2025-08-19 17:46:03.505', 10605, 3358, 20),
(NULL, 'placed an order for ', '2025-08-19 17:46:39.209', 10605, 3359, 23),
(NULL, 'The will go through our price list and get back', '2025-08-19 17:49:41.124', 10605, 3360, 20),
(NULL, 'to access movement of vapes over the weekend and give feedback on Monday on placing an order', '2025-08-19 18:03:37.987', 10605, 3361, 23),
(NULL, 'placed an order ', '2025-08-19 18:04:46.964', 10605, 3362, 10),
(NULL, 'updated ', '2025-08-19 18:09:19.651', 10605, 3363, 23),
(NULL, '*38pcs 3000 puffs and 13 PCs 9000 puffs', '2025-08-19 18:32:49.854', 10605, 3364, 7),
(NULL, 'we have carried 8pcs of 2500 puffs for an exchange ', '2025-08-19 18:41:46.294', 10605, 3365, 23),
(NULL, 'manager said I should try next week perhaps I might get some customers for they can allow me to sell directly here.', '2025-08-19 19:08:24.136', 10605, 3366, 124),
(NULL, 'we have placed an order of pouches and vapes.Outlet complaining that our display is small.', '2025-08-19 19:41:35.070', 10605, 3367, 5),
(NULL, 'slow movement of our products ', '2025-08-20 09:49:46.462', 10605, 3368, 109),
(NULL, '15 pieces remaining ', '2025-08-20 10:26:45.193', 10605, 3369, 6),
(NULL, '15 pieces remaining ', '2025-08-20 10:27:03.627', 10605, 3370, 6),
(NULL, 'progressing on so well ', '2025-08-20 10:31:13.915', 10605, 3371, 109),
(NULL, '*12 PCs 3000 puffsand 3 pcs 9000 puffs ', '2025-08-20 10:37:01.004', 10605, 3372, 7),
(NULL, 'progressing on so well ', '2025-08-20 10:40:37.693', 10605, 3373, 109),
(NULL, 'To place an order from S Liquor ', '2025-08-20 10:55:20.047', 10605, 3374, 28),
(NULL, 'they have never received their previous order for both vapes and pouches ', '2025-08-20 10:58:37.886', 10605, 3375, 6),
(NULL, 'They will pay the pending payment of ksh 4,280 on next week Monday ', '2025-08-20 11:05:37.523', 10605, 3376, 23),
(NULL, 'Well stocked', '2025-08-20 11:07:36.441', 10605, 3377, 57),
(NULL, 'updated ', '2025-08-20 11:09:02.471', 10605, 3378, 23),
(NULL, 'he well call me when is read to get', '2025-08-20 11:14:12.604', 10605, 3379, 71),
(NULL, 'They are also waiting for order from Hq', '2025-08-20 11:20:13.230', 10605, 3380, 69),
(NULL, 'We have a proposed order to be done', '2025-08-20 11:27:25.200', 10605, 3381, 5),
(NULL, 'we have a proposed order to be done.Issues with displaying', '2025-08-20 11:27:58.031', 10605, 3382, 5),
(NULL, 'He told me that he will take one strawberry ice cream today', '2025-08-20 11:29:04.733', 10605, 3383, 68),
(NULL, 'I am suggesting 3000 puffs at this branch because of slow movement', '2025-08-20 11:29:51.759', 10605, 3384, 2),
(NULL, 'Picked sweet min, 5 dots. They had been promised an exchange in April by the previous rep but it was never done. I will get feedback on reonboarding our products next week Monday ', '2025-08-20 11:33:32.387', 10605, 3385, 23),
(NULL, 'well stocked for now ', '2025-08-20 11:34:50.831', 10605, 3386, 28),
(NULL, 'Slow movement but client is okay.', '2025-08-20 11:46:51.687', 10605, 3387, 2),
(NULL, 'Also waiting for order from Hq', '2025-08-20 11:53:58.753', 10605, 3388, 69),
(NULL, '9k puffs selling at 3000 bob a piece because of Dantra pricing.', '2025-08-20 11:55:24.981', 10605, 3389, 2),
(NULL, 'placed an order for 10 pcs', '2025-08-20 11:55:42.557', 10605, 3390, 7),
(NULL, 'slow movement.hart doing better than us.we also agreed to topup 8pcs 9000 puffs and 12pcs 3000 pufss', '2025-08-20 12:00:39.408', 10605, 3391, 5),
(NULL, 'well stocked for now ', '2025-08-20 12:01:55.152', 10605, 3392, 28),
(NULL, 'we have placed an order 12pcs 9000 puffs..and 10pcs cooling mint', '2025-08-20 12:28:23.335', 10605, 3393, 5),
(NULL, 'Client says movement is okay. no complaints', '2025-08-20 12:31:23.379', 10605, 3394, 2),
(NULL, 'Yesterday they placed an order of vapes and pouches ', '2025-08-20 12:50:12.646', 10605, 3395, 28),
(NULL, 'manager said she will call me', '2025-08-20 12:51:27.250', 10605, 3396, 125),
(NULL, 'We need to place orders for woosh but the manager is a bit hesitant about our products ', '2025-08-20 12:57:34.031', 10605, 3397, 20),
(NULL, 'she closed for a short time I will come next time ', '2025-08-20 13:06:12.458', 10605, 3398, 68),
(NULL, '*they have 26 PCs 9000 puffs and 31pcs pouches ', '2025-08-20 13:08:39.020', 10605, 3399, 7),
(NULL, 'I will communicate with Mr Patrick to see how many pieces remained here after distribution to calculate the number of sales ', '2025-08-20 13:13:43.045', 10605, 3400, 68),
(NULL, 'they said they will call me', '2025-08-20 13:14:37.320', 10605, 3401, 125),
(NULL, 'expecting an order', '2025-08-20 13:18:06.625', 10605, 3402, 46),
(NULL, 'Slow movement on vapes', '2025-08-20 13:23:09.293', 10605, 3403, 2),
(NULL, 'The manager is absent I called him and he told me that they have a meeting so it\'s better I come tomorrow ', '2025-08-20 13:28:18.029', 10605, 3404, 68),
(NULL, 'they will get an approval from management and give an order.', '2025-08-20 13:32:34.228', 10605, 3405, 23),
(NULL, 'well stocked for now ', '2025-08-20 13:35:11.369', 10605, 3406, 28),
(NULL, 'well stocked', '2025-08-20 13:39:27.849', 10605, 3407, 46),
(NULL, '*waiting for their order to be delivered ', '2025-08-20 13:37:42.458', 10605, 3408, 7),
(NULL, 'The one who is responsible will be available tomorrow ', '2025-08-20 13:41:41.411', 10605, 3409, 68),
(NULL, 'updated ', '2025-08-20 13:42:31.085', 10605, 3410, 23),
(NULL, 'They opted to sell the Goldpouch as a single pouch @ksh 40 to boost sales. They received their exchange of the 3 dots to 5 dots on Monday.', '2025-08-20 13:44:27.012', 10605, 3411, 23),
(NULL, 'collection of cheque', '2025-08-20 13:45:47.184', 10605, 3412, 5),
(NULL, 'change of dates on cheque for them to receive their order.', '2025-08-20 13:47:30.544', 10605, 3413, 5),
(NULL, 'well displayed ', '2025-08-20 13:51:04.813', 10605, 3414, 46),
(NULL, 'he likes my products but when is ready he will call me ', '2025-08-20 14:01:51.801', 10605, 3415, 71),
(NULL, '*to place order after stock take', '2025-08-20 14:00:35.279', 10605, 3416, 7),
(NULL, 'few pieces remaining though Stock is moving slowly ', '2025-08-20 14:06:17.206', 10605, 3417, 6),
(NULL, 'well stocked for now ', '2025-08-20 14:08:21.299', 10605, 3418, 28),
(NULL, 'they like my products but he will check me another time ', '2025-08-20 14:10:56.824', 10605, 3419, 71),
(NULL, 'out of stock', '2025-08-20 14:12:18.215', 10605, 3420, 46),
(NULL, 'They have placed an order for 60 pouches and 50 vapes', '2025-08-20 14:17:44.429', 10605, 3421, 5),
(NULL, 'The manager really like our products and ready to take his order next week', '2025-08-20 14:19:42.054', 10605, 3422, 102),
(NULL, '4 pieces remaining they should restock before friday', '2025-08-20 14:22:40.200', 10605, 3423, 6),
(NULL, 'requested an exchange of the fresh Lychee and dawa cocktail with sun kissed grape and frost apple, 5 PCs in total.', '2025-08-20 14:27:28.861', 10605, 3424, 23),
(NULL, 'well stocked', '2025-08-20 14:29:46.707', 10605, 3425, 46),
(NULL, 'not bad movement but it take long time', '2025-08-20 14:35:34.860', 10605, 3426, 70),
(NULL, 'well stocked ', '2025-08-20 14:46:45.024', 10605, 3427, 28),
(NULL, 'Slow vape movement, pouches okay', '2025-08-20 14:55:15.729', 10605, 3428, 2),
(NULL, 'Movement is okay', '2025-08-20 15:00:30.981', 10605, 3429, 2),
(NULL, 'The boss wasn\'t around so I get her number so that we can talk ', '2025-08-20 15:00:48.217', 10605, 3430, 102),
(NULL, 'Stock in plenty ', '2025-08-20 15:09:57.155', 10605, 3431, 6),
(NULL, 'like our products ', '2025-08-20 15:13:23.102', 10605, 3432, 70),
(NULL, 'out of stock', '2025-08-20 15:24:36.156', 10605, 3433, 46),
(NULL, 'the product is slow moving. Since last month they. have sold 1 PC for the woosh vape', '2025-08-20 15:26:26.692', 10605, 3434, 23),
(NULL, 'I proposed we issue a demand letter since the client is proving difficult to pay pending invoice ', '2025-08-20 15:27:55.084', 10605, 3435, 23),
(NULL, 'they don\'t sell vapes currently but when ready they will give us a call', '2025-08-20 15:28:47.355', 10605, 3436, 102),
(NULL, 'Velo has literally killed our pouches', '2025-08-20 15:33:28.376', 10605, 3437, 2),
(NULL, 'I propose we give a demand letter to collect the pending payment since client is proving to be difficult ', '2025-08-20 15:36:18.503', 10605, 3438, 23),
(NULL, 'updating client on order status after client has been waiting for almost 3 weeks to place their order. assured them they will receive before Friday. ', '2025-08-20 15:37:02.403', 10605, 3439, 57),
(NULL, 'We have placed a new order ', '2025-08-20 15:38:03.622', 10605, 3440, 5),
(NULL, 'we have placed a new order', '2025-08-20 15:39:00.618', 10605, 3441, 5),
(NULL, 'on the prior conversation stage', '2025-08-20 15:41:25.491', 10605, 3442, 70),
(NULL, 'slow movement of our products ', '2025-08-20 15:46:17.741', 10605, 3443, 109),
(NULL, 'we placed an order', '2025-08-20 15:46:53.483', 10605, 3444, 5),
(NULL, '.', '2025-08-20 15:48:32.902', 10605, 3445, 70),
(NULL, 'Generally slow movement ', '2025-08-20 15:51:48.551', 10605, 3446, 2),
(NULL, 'he like my products but for now is not ready ', '2025-08-20 15:52:39.374', 10605, 3447, 71),
(NULL, '*waiting for the delivery ', '2025-08-20 15:55:23.336', 10605, 3448, 7),
(NULL, 'well stocked', '2025-08-20 15:57:37.854', 10605, 3449, 46),
(NULL, 'Slow movement of general products', '2025-08-20 16:04:40.861', 10605, 3450, 2),
(NULL, 'Sales are beginning to improve at this outlet ', '2025-08-20 16:17:00.886', 10605, 3451, 57),
(NULL, 'Tried to contact the ownerbhe wasnt available', '2025-08-20 16:18:38.434', 10605, 3452, 5),
(NULL, '*they have 56 PCs 3000 puffs and 18 PCs 9000 puffs ', '2025-08-20 16:17:30.500', 10605, 3453, 7),
(NULL, '*the lady in charge of liquor is not in we will place order next week ', '2025-08-20 16:18:14.302', 10605, 3454, 7),
(NULL, 'Getting them to stock vapes too.', '2025-08-20 16:26:56.365', 10605, 3455, 2),
(NULL, 'placed an order ', '2025-08-20 16:29:53.539', 10605, 3456, 23),
(NULL, 'Ray gave feedback that he doesn\'t have a go ahead to place orders and also was informed by Tanya that we ares sorting the display issue in Kiambu ', '2025-08-20 16:54:02.454', 10605, 3457, 23),
(NULL, '*they will place order for pouches,they don\'t have for now', '2025-08-20 16:55:04.430', 10605, 3458, 7),
(NULL, 'Will topup 9000 puffs ehen codes are unblovked', '2025-08-20 16:58:52.568', 10605, 3459, 5),
(NULL, 'They have 3lpos that will be delivered with all skus', '2025-08-20 17:09:05.431', 10605, 3460, 5),
(NULL, 'I have picked 1 PC of faulty vape to be exchanged tomorrow ', '2025-08-20 17:09:58.212', 10605, 3461, 23),
(NULL, 'well stocked for now ', '2025-08-20 17:31:16.298', 10605, 3462, 28),
(NULL, 'did an exchange 5 9000 puffs', '2025-08-20 17:38:55.932', 10605, 3463, 5),
(NULL, 'they still have stock but they will place order for pouches on Saturday ', '2025-08-20 17:38:48.408', 10605, 3464, 7),
(NULL, '*waiting to receive their order', '2025-08-20 17:45:40.389', 10605, 3465, 7),
(NULL, 'well stocked for now ', '2025-08-20 18:03:20.711', 10605, 3466, 28),
(NULL, 'They will place order for 9000 puffs.will do a grn for slow moving 3dots too.\nmemo was sent for them to remove the displays from their outlet.', '2025-08-20 18:50:15.621', 10605, 3467, 5),
(NULL, 'order to be placed from hq', '2025-08-20 19:33:32.113', 10605, 3468, 20),
(NULL, 'order ', '2025-08-20 19:34:40.919', 10605, 3469, 20),
(NULL, 'well stocked', '2025-08-21 11:26:14.626', 10605, 3470, 109),
(NULL, 'good sales', '2025-08-21 11:47:20.410', 10605, 3471, 124),
(NULL, '28 pieces remaining pushing for a reorder ', '2025-08-21 11:57:03.210', 10605, 3472, 6),
(NULL, 'they received their order of 9000puffs 10 pieces', '2025-08-21 12:28:58.945', 10605, 3473, 6),
(NULL, 'customer has suggest that we put up mini posters for advertisment to see if users will respond', '2025-08-21 12:33:23.917', 10605, 3474, 124),
(NULL, 'will order next week', '2025-08-21 12:57:03.352', 10605, 3475, 16),
(NULL, '*they will place order for pouches once they receive a display ', '2025-08-21 12:56:05.089', 10605, 3476, 7),
(NULL, 'the manager told me to come next time ', '2025-08-21 13:02:10.564', 10605, 3477, 68),
(NULL, 'He will take soon', '2025-08-21 13:15:46.403', 10605, 3478, 68),
(NULL, 'they like our products but not yet to take', '2025-08-21 13:22:09.890', 10605, 3479, 102),
(NULL, 'he will call me ', '2025-08-21 13:34:44.143', 10605, 3480, 71),
(NULL, 'I gonna do activation ', '2025-08-21 13:36:04.770', 10605, 3481, 70),
(NULL, 'he will call me when boss is back', '2025-08-21 13:39:04.572', 10605, 3482, 71),
(NULL, '*the product are not moving ', '2025-08-21 13:50:12.121', 10605, 3483, 7),
(NULL, 'they still pushing to the end users but not yet selling ', '2025-08-21 14:01:15.857', 10605, 3484, 102),
(NULL, 'see Friday ', '2025-08-21 14:03:07.719', 10605, 3485, 70),
(NULL, 'Did not receive their order ', '2025-08-21 14:09:35.163', 10605, 3486, 57),
(NULL, '*they still have products ', '2025-08-21 14:18:29.526', 10605, 3487, 7),
(NULL, 'order delivery', '2025-08-21 14:23:52.638', 10605, 3488, 57),
(NULL, 'made an order ', '2025-08-21 14:28:14.973', 10605, 3489, 16),
(NULL, 'not good movement ', '2025-08-21 14:38:50.012', 10605, 3490, 70),
(NULL, 'No Woosh Stock ', '2025-08-21 14:54:14.454', 10605, 3491, 2),
(NULL, 'Trying to get an order', '2025-08-21 14:57:53.617', 10605, 3492, 2),
(NULL, 'they are returning 21pcs of pouches in exchange of woosh vapes', '2025-08-21 15:00:54.522', 10605, 3493, 59),
(NULL, 'No other brand, Velo only.', '2025-08-21 15:04:13.579', 10605, 3494, 2),
(NULL, 'waiting for their Stock to be delivered. ', '2025-08-21 15:13:14.367', 10605, 3495, 6),
(NULL, 'No stocks yet', '2025-08-21 15:30:57.723', 10605, 3496, 2),
(NULL, 'took 12pcs of 3000puff for exchange of flavors ', '2025-08-21 15:31:25.266', 10605, 3497, 59),
(NULL, 'To place an order soon ', '2025-08-21 15:32:24.081', 10605, 3498, 28),
(NULL, 'Chasing an order', '2025-08-21 15:35:51.286', 10605, 3499, 2),
(NULL, 'we have placed an order for 15vapes and 10strawberry pouches', '2025-08-21 15:39:01.067', 10605, 3500, 5),
(NULL, 'they have our products and still pushing to the market ', '2025-08-21 15:45:46.315', 10605, 3501, 102),
(NULL, 'They will place an order for 10 minty and 10 chizi.', '2025-08-21 16:07:33.499', 10605, 3502, 5),
(NULL, '3 pieces remaining to make a reorder ', '2025-08-21 16:07:59.083', 10605, 3503, 6),
(NULL, 'will place their order when the owner comes.The attendant says the owner had given an order but was never received from our end.', '2025-08-21 16:26:26.916', 10605, 3504, 23),
(NULL, 'good movement.placed an order of 20pcs 9000 puffs', '2025-08-21 16:27:13.599', 10605, 3505, 5),
(NULL, 'I followed up on whispers didn\'t find the manager, I was told he\'s on a trip I\'ll check again when he\'s back', '2025-08-21 16:28:32.293', 10605, 3506, 124),
(NULL, 'Minty snow moving fast,the rest of slow moving picked', '2025-08-21 16:42:53.380', 10605, 3507, 2),
(NULL, 'osuba will do an order on saturday for thr 9000 puffs and remaining flavors 3000 puffs', '2025-08-21 16:44:08.936', 10605, 3508, 5),
(NULL, '4pcs left', '2025-08-21 16:45:02.993', 10605, 3509, 2),
(NULL, 'There\'s an up coming event which will take place at 19th Bar ', '2025-08-21 16:46:29.305', 10605, 3510, 28),
(NULL, 'owner does not sell any kind of smokes ', '2025-08-21 16:47:12.366', 10605, 3511, 124),
(NULL, 'Owner to approve order placement', '2025-08-21 16:52:59.608', 10605, 3512, 2),
(NULL, 'Slow but steady movement of Stock.', '2025-08-21 17:01:22.395', 10605, 3513, 2),
(NULL, 'well stocked for now ', '2025-08-21 17:14:58.979', 10605, 3514, 28),
(NULL, 'Following up on an order', '2025-08-21 17:38:51.782', 10605, 3515, 20),
(NULL, 'will make payments for 20750 on 30th August.', '2025-08-21 17:47:13.264', 10605, 3516, 23),
(NULL, 'To place their order tomorrow ', '2025-08-21 17:59:57.229', 10605, 3517, 28),
(NULL, 'the procurement officer promised to give an order soon. I also got her contact ', '2025-08-21 18:01:40.445', 10605, 3518, 23),
(NULL, 'only 3pcs remaining ', '2025-08-21 18:04:51.503', 10605, 3519, 20),
(NULL, 'having a pending ', '2025-08-21 18:07:05.555', 10605, 3520, 20),
(NULL, 'To place an order from S Liquor before end of this week ', '2025-08-21 18:19:42.494', 10605, 3521, 28),
(NULL, 'they are making order', '2025-08-21 19:43:14.056', 10605, 3522, 125),
(NULL, 'poor progress ', '2025-08-22 09:10:22.281', 10605, 3523, 109),
(NULL, 'progressing on so well ', '2025-08-22 09:47:08.941', 10605, 3524, 109),
(NULL, 'made an order but didn\'t receive all the flavors ', '2025-08-22 10:55:26.623', 10605, 3525, 6),
(NULL, 'made an order', '2025-08-22 11:00:41.027', 10605, 3526, 16),
(NULL, '*they placed an order of 7 PCs yesterday from distributor ', '2025-08-22 11:36:06.844', 10605, 3527, 7),
(NULL, 'progressing on well', '2025-08-22 11:44:04.819', 10605, 3528, 109),
(NULL, 'following up on payments. ', '2025-08-22 12:00:08.876', 10605, 3529, 57),
(NULL, 'well displayed ', '2025-08-22 12:15:25.738', 10605, 3530, 109),
(NULL, 'progressing on so well', '2025-08-22 12:21:43.535', 10605, 3531, 109),
(NULL, 'They loved the product but the manager was not here have traved they said on monday i should come back ', '2025-08-22 12:35:07.610', 10605, 3532, 69),
(NULL, 'moving on so well ', '2025-08-22 12:40:04.289', 10605, 3533, 109),
(NULL, 'To place an order today ', '2025-08-22 12:58:04.497', 10605, 3534, 28),
(NULL, '*we have place order for flavours they didn\'t have ', '2025-08-22 12:56:58.059', 10605, 3535, 7),
(NULL, 'received their pouches to order 9000 puffs flavors', '2025-08-22 13:09:20.181', 10605, 3536, 5),
(NULL, 'very poor sales', '2025-08-22 13:10:27.788', 10605, 3537, 57),
(NULL, '*we have placed an order of 18 PCs for flavours they didn\'t have ', '2025-08-22 13:10:16.531', 10605, 3538, 7),
(NULL, '26pcs in total. slow movement', '2025-08-22 13:16:59.289', 10605, 3539, 2),
(NULL, 'I visited again and the boss is not around so they don\'t have the answer until the boss is around ', '2025-08-22 13:27:27.865', 10605, 3540, 102),
(NULL, '*we Will place an order next week once dantra is supplied with stock ', '2025-08-22 13:43:45.980', 10605, 3541, 7),
(NULL, 'well stocked for now ', '2025-08-22 13:48:23.782', 10605, 3542, 28),
(NULL, '*to place order from distributor ', '2025-08-22 13:52:20.534', 10605, 3543, 7),
(NULL, 'Codes blocked but following up', '2025-08-22 14:00:02.039', 10605, 3544, 5),
(NULL, 'we have placed an order for the 9000 puffs 12pcs and 11pcs 3000 puffs', '2025-08-22 14:09:26.821', 10605, 3545, 5),
(NULL, 'need to talk to owner.', '2025-08-22 14:24:11.588', 10605, 3546, 124),
(NULL, 'they still going on sales and no current progress ', '2025-08-22 14:32:46.068', 10605, 3547, 102),
(NULL, 'the progress is slow but still hoping will make it', '2025-08-22 14:44:57.425', 10605, 3548, 102),
(NULL, 'need to check with owner,, will call me when ready', '2025-08-22 14:49:19.947', 10605, 3549, 124),
(NULL, 'product going slow ', '2025-08-22 14:53:09.669', 10605, 3550, 71),
(NULL, 'well stocked for now ', '2025-08-22 14:54:58.244', 10605, 3551, 28),
(NULL, 'out of stock placed an order for 24 vapes and 10 pouches ', '2025-08-22 15:01:02.062', 10605, 3552, 6),
(NULL, 'gotten an order 9000 puffs 12 and 11pcs 3000 puffs', '2025-08-22 15:01:41.187', 10605, 3553, 5),
(NULL, 'gotten an order', '2025-08-22 15:02:16.654', 10605, 3554, 5),
(NULL, 'only four pieces left.have placed an order for 10pcs 9000 puffs', '2025-08-22 15:06:08.130', 10605, 3555, 5),
(NULL, 'he like my products but she will call me', '2025-08-22 15:11:24.439', 10605, 3556, 71),
(NULL, 'they have our products and already sold out 2 pcs ', '2025-08-22 15:31:27.647', 10605, 3557, 102),
(NULL, 'they have our products and already sold out 2 pcs ', '2025-08-22 15:34:51.927', 10605, 3558, 102),
(NULL, 'Slow movement. Hart moves faster here than Woosh', '2025-08-22 15:39:43.442', 10605, 3559, 2),
(NULL, 'only had 2 pcsxof 3000 puffs.they will place an order on monday for both 3k and 9k puffs', '2025-08-22 15:42:57.393', 10605, 3560, 5),
(NULL, 'need to think about it', '2025-08-22 15:43:42.772', 10605, 3561, 124),
(NULL, 'they promised to call me back ', '2025-08-22 15:47:19.304', 10605, 3562, 68),
(NULL, 'Slow movement of 9k puffs,returning for exchange with other flavors', '2025-08-22 15:51:57.775', 10605, 3563, 2),
(NULL, 'Manager not in so they told me to come next week', '2025-08-22 15:53:06.814', 10605, 3564, 124),
(NULL, 'to place an order today', '2025-08-22 16:18:38.933', 10605, 3565, 5),
(NULL, 'Managers told me that they don\'t have a good way to manage the product so he advised me to sell directly to the users', '2025-08-22 16:29:02.196', 10605, 3566, 124),
(NULL, 'Proposed an exchange of pinacolada and mango to minty snow and passion', '2025-08-22 16:38:02.432', 10605, 3567, 2),
(NULL, 'placing order', '2025-08-22 16:38:24.928', 10605, 3568, 57),
(NULL, 'to proceed with the lpo that was shared on monday', '2025-08-22 16:55:09.327', 10605, 3569, 5),
(NULL, 'pushing for an order', '2025-08-22 17:36:24.370', 10605, 3570, 6),
(NULL, '* out of stock ', '2025-08-22 17:40:32.703', 10605, 3571, 7),
(NULL, 'push for an order ', '2025-08-22 18:26:32.600', 10605, 3572, 6),
(NULL, 'progressing well ', '2025-08-23 09:23:44.173', 10605, 3573, 109),
(NULL, 'progressing well ', '2025-08-23 10:38:50.140', 10605, 3574, 109),
(NULL, 'progressing well ', '2025-08-23 10:42:00.873', 10605, 3575, 109),
(NULL, 'they have limited stock purchase because of their end month report.will place an order first week of September ', '2025-08-23 11:01:30.044', 10605, 3576, 23),
(NULL, 'The owner said I call her on Monday. Currently selling hart and I\'m trying to reonboard this client ', '2025-08-23 11:32:08.272', 10605, 3577, 23),
(NULL, 'Pouches slow moving ', '2025-08-23 12:01:59.272', 10605, 3578, 2),
(NULL, 'I have forwarded the available flavors to the attendant. she will share with the owner to place an order.', '2025-08-23 12:02:55.114', 10605, 3579, 23),
(NULL, 'progressing on so well', '2025-08-23 12:07:25.507', 10605, 3580, 109),
(NULL, 'progressing on so well ', '2025-08-23 12:09:29.808', 10605, 3581, 109),
(NULL, 'moving so well', '2025-08-23 12:14:51.642', 10605, 3582, 109),
(NULL, 'Moved on to Velo', '2025-08-23 12:22:56.150', 10605, 3583, 2),
(NULL, 'updated ', '2025-08-23 12:28:47.665', 10605, 3584, 23),
(NULL, 'moving well', '2025-08-23 12:36:40.967', 10605, 3585, 109),
(NULL, 'placed an order for 24 vapes', '2025-08-23 12:37:41.485', 10605, 3586, 23),
(NULL, 'not yet placed an order for 9000 puffs to place next week', '2025-08-23 12:43:12.076', 10605, 3587, 5),
(NULL, 'they call me me after talk with the owner ', '2025-08-23 13:07:12.848', 10605, 3588, 71),
(NULL, 'wipl lace am order for 9000 puffs next week.selling under the conter contributing to slow movement', '2025-08-23 13:08:59.943', 10605, 3589, 5),
(NULL, 'will ordrr 9000 puffs next week', '2025-08-23 13:09:48.715', 10605, 3590, 5),
(NULL, 'we will do an exchange of chilly lemon, dawa cocktail and I\'ve sparkling orange when Dantra has 9000 puffs stocks', '2025-08-23 13:12:15.943', 10605, 3591, 23),
(NULL, 'to place an order for 9000 puffs missing flavors', '2025-08-23 13:12:29.352', 10605, 3592, 5),
(NULL, 'Had a meeting with the owner and mentioned she wasn\'t really financially ', '2025-08-23 13:13:38.764', 10605, 3593, 16),
(NULL, 'updated ', '2025-08-23 13:27:01.137', 10605, 3594, 23),
(NULL, 'We introduced woosh vapes this month and has sold 4 PCs. The vape has potential in this outlet ', '2025-08-23 13:43:30.699', 10605, 3595, 23),
(NULL, 'still the owner isn\'t sure if he\'ll get customers for vapes', '2025-08-23 14:07:30.191', 10605, 3596, 124),
(NULL, 'owner can\'t take the product', '2025-08-23 14:23:12.188', 10605, 3597, 124),
(NULL, 'theres a challenge on placing order in naivas buruburu ..', '2025-08-23 14:29:44.049', 10605, 3598, 5),
(NULL, 'I had requested them to place an order for the 3000 puffs an ppuches amd nothing yet.o have a challenge with that outlet onnplacing orders', '2025-08-23 14:30:36.383', 10605, 3599, 5),
(NULL, 'already sold out 1 pcs', '2025-08-23 15:16:33.959', 10605, 3600, 102),
(NULL, 'they have advise that I take the product back to their restaurant ', '2025-08-23 17:12:57.244', 10605, 3601, 124),
(NULL, 'Delivering Order. ', '2025-08-23 17:28:14.554', 10605, 3602, 57),
(NULL, 'Activation ', '2025-08-23 19:39:28.704', 10605, 3603, 57),
(NULL, 'feedback ', '2025-08-24 14:37:43.521', 10605, 3604, 94),
(NULL, 'progressing well ', '2025-08-25 09:26:19.156', 10605, 3605, 109),
(NULL, 'progressing on so well ', '2025-08-25 09:43:37.683', 10605, 3606, 109),
(NULL, 'still 10 pcs ', '2025-08-25 12:15:08.270', 10605, 3607, 69),
(NULL, 'owner said I waita little longer ', '2025-08-25 12:33:22.897', 10605, 3608, 16),
(NULL, 'owner says the pub is still new so not sure if they\'ll get customers... she advised me to come back next month', '2025-08-25 12:58:14.865', 10605, 3609, 124),
(NULL, 'they are not ready to order yet.. but promise to take on credit though', '2025-08-25 13:19:00.918', 10605, 3610, 124),
(NULL, '4pcs in stock ', '2025-08-25 13:33:21.342', 10605, 3611, 7),
(NULL, 'we are on the conversation stage not yet reaching the conclusion ', '2025-08-25 13:38:56.742', 10605, 3612, 102),
(NULL, 'appointment for next week ', '2025-08-25 13:42:26.067', 10605, 3613, 70),
(NULL, 'the manager like the product but for a time to discuss with the owner ', '2025-08-25 14:05:39.236', 10605, 3614, 102),
(NULL, 'the manager ask for a time to discuss with the owner ', '2025-08-25 14:13:31.106', 10605, 3615, 102),
(NULL, 'progressing well', '2025-08-25 14:16:31.756', 10605, 3616, 109),
(NULL, '4pcs ', '2025-08-25 14:35:13.455', 10605, 3617, 7),
(NULL, '.', '2025-08-25 14:47:37.671', 10605, 3618, 102),
(NULL, 'the manager is not around so I will be back when he is back', '2025-08-25 14:54:57.534', 10605, 3619, 102),
(NULL, 'good movement ', '2025-08-25 15:09:17.216', 10605, 3620, 70),
(NULL, 'to make an order by next week.', '2025-08-25 15:14:04.052', 10605, 3621, 6),
(NULL, 'have 3000puffs 8pcs and 9000 puffs 12 pc', '2025-08-25 15:18:06.086', 10605, 3622, 7),
(NULL, '*3000 puffs 8pcs and 9000 puffs 12 pcs', '2025-08-25 15:22:10.596', 10605, 3623, 7),
(NULL, 'progressing on so well ', '2025-08-25 15:31:03.734', 10605, 3624, 109),
(NULL, 'the manager like our products and accept to make the order on  first September ', '2025-08-25 15:41:00.176', 10605, 3625, 70),
(NULL, 'client not sure if it can move there they need more time', '2025-08-25 16:01:28.502', 10605, 3626, 124),
(NULL, 'the owner still haven\'t give a go ahade so no orders from them', '2025-08-25 16:04:36.301', 10605, 3627, 124),
(NULL, '*hart and velo selling more ', '2025-08-25 16:05:48.232', 10605, 3628, 7),
(NULL, 'still the going good to push ', '2025-08-25 16:34:03.264', 10605, 3629, 71),
(NULL, 'manager not around and not picking my calls', '2025-08-25 17:04:11.936', 10605, 3630, 59),
(NULL, 'she call me when is ready ', '2025-08-25 17:11:22.166', 10605, 3631, 71),
(NULL, 'waiting for the owner to make a new order', '2025-08-25 17:31:22.387', 10605, 3632, 59),
(NULL, 'wellstocked', '2025-08-25 18:22:18.824', 10605, 3633, 6),
(NULL, 'They are well stocked ', '2025-08-25 18:44:52.482', 10605, 3634, 28),
(NULL, 'still have stock ', '2025-08-25 19:07:50.407', 10605, 3635, 6),
(NULL, 'well stocked ', '2025-08-25 19:11:41.755', 10605, 3636, 28),
(NULL, 'moving out so well', '2025-08-26 09:37:01.665', 10605, 3637, 109),
(NULL, 'progressing on so well', '2025-08-26 10:01:02.839', 10605, 3638, 109),
(NULL, '*following up on Payments ', '2025-08-26 10:12:01.736', 10605, 3639, 7),
(NULL, 'progressing on so well', '2025-08-26 10:43:01.854', 10605, 3640, 109),
(NULL, '*we will place an order by the end of this week ', '2025-08-26 10:44:55.347', 10605, 3641, 7),
(NULL, 'trying to get pending balance', '2025-08-26 10:48:35.720', 10605, 3642, 59),
(NULL, 'will place an order once the stock for the woosh vapes reduces', '2025-08-26 10:50:51.537', 10605, 3643, 23),
(NULL, 'velo has taken over our pouches', '2025-08-26 11:05:14.425', 10605, 3644, 59),
(NULL, 'to place order by the end of this week ', '2025-08-26 11:19:03.963', 10605, 3645, 7),
(NULL, 'They had no stocks.Order proposed to be placed on wed and received on Thursday.', '2025-08-26 11:23:52.409', 10605, 3646, 5),
(NULL, '*waiting for their order to be delivered for 9000 puffs', '2025-08-26 11:24:32.268', 10605, 3647, 7),
(NULL, '*waiting for their order to be delivered for 9000 puffs', '2025-08-26 11:27:23.616', 10605, 3648, 7),
(NULL, 'selling velo and its moving well', '2025-08-26 11:29:49.695', 10605, 3649, 59),
(NULL, 'minty snow is not selling ', '2025-08-26 11:33:00.015', 10605, 3650, 20),
(NULL, 'made and order', '2025-08-26 11:35:06.187', 10605, 3651, 16),
(NULL, 'order for vapes placed to Dantra', '2025-08-26 11:42:12.933', 10605, 3652, 20),
(NULL, 'progressing on so well', '2025-08-26 12:01:56.125', 10605, 3653, 109),
(NULL, 'Making their payments tomorrow an d place another order ', '2025-08-26 12:16:31.831', 10605, 3654, 23),
(NULL, 'waiting for their replaced order', '2025-08-26 12:20:02.425', 10605, 3655, 59),
(NULL, 'They have no 9000 puffs will place order after they unblock.', '2025-08-26 12:28:28.987', 10605, 3656, 5),
(NULL, 'progressing on so well ', '2025-08-26 12:37:18.420', 10605, 3657, 109),
(NULL, 'Order to be done tomorrow ', '2025-08-26 12:38:13.793', 10605, 3658, 20),
(NULL, 'made an ord', '2025-08-26 12:39:21.994', 10605, 3659, 16),
(NULL, '*the product is moving very slow ', '2025-08-26 12:47:36.721', 10605, 3660, 7),
(NULL, '*the product is moving very slow for now ', '2025-08-26 12:50:27.288', 10605, 3661, 7),
(NULL, 'they still not reaching the conclusion but showing interest on taking our products ', '2025-08-26 12:56:11.631', 10605, 3662, 102),
(NULL, 'requesting an exchange of chilly lemon caramel hazelnut  and Fresh Lychee ', '2025-08-26 12:57:17.554', 10605, 3663, 23),
(NULL, 'wasn\'t able to m', '2025-08-26 13:03:04.598', 10605, 3664, 16),
(NULL, 'Order will be done on first', '2025-08-26 13:17:14.228', 10605, 3665, 20),
(NULL, 'like our products ', '2025-08-26 13:18:12.727', 10605, 3666, 70),
(NULL, 'Order will be placed from 1st', '2025-08-26 13:23:01.698', 10605, 3667, 20),
(NULL, '*all most out of stock we have been placing order but they are not receiving the products ', '2025-08-26 13:23:54.748', 10605, 3668, 7),
(NULL, 'placed an order', '2025-08-26 13:26:42.834', 10605, 3669, 23),
(NULL, 'the manager is not around but the seller promise to tell him that I visited again', '2025-08-26 13:30:48.845', 10605, 3670, 102),
(NULL, 'not sold', '2025-08-26 13:37:07.288', 10605, 3671, 70),
(NULL, 'Outlet is well stocked', '2025-08-26 13:47:38.384', 10605, 3672, 5),
(NULL, 'supervisor said will call when has clients for vapes', '2025-08-26 14:08:30.887', 10605, 3673, 124),
(NULL, 'Well stocked on pouches and 3000 puffs..To place an order on 9000 puffs', '2025-08-26 14:09:01.804', 10605, 3674, 5),
(NULL, 'placed an order ', '2025-08-26 14:10:04.455', 10605, 3675, 23),
(NULL, 'nice movement ', '2025-08-26 14:36:04.820', 10605, 3676, 70),
(NULL, 'No pouches but talked to BAC to plsce an order', '2025-08-26 14:42:08.618', 10605, 3677, 5),
(NULL, 'he like my products so he will check me ', '2025-08-26 14:48:44.787', 10605, 3678, 71),
(NULL, '.', '2025-08-26 14:49:13.972', 10605, 3679, 70),
(NULL, 'still they don’t give me a good answer ', '2025-08-26 14:52:52.545', 10605, 3680, 71),
(NULL, 'currently expanding the club hence could not engage the manager ', '2025-08-26 15:01:18.707', 10605, 3681, 23),
(NULL, 'placed an order ', '2025-08-26 15:21:07.590', 10605, 3682, 23),
(NULL, 'They have placed an order of 5 every piece', '2025-08-26 15:24:19.990', 10605, 3683, 5),
(NULL, 'To place an order from S Liquor this week ', '2025-08-26 15:36:56.713', 10605, 3684, 28),
(NULL, 'well stocked for now ', '2025-08-26 15:45:18.341', 10605, 3685, 28),
(NULL, 'I’ll visit on Saturday to meet the owner', '2025-08-26 16:05:00.456', 10605, 3686, 20),
(NULL, 'increase in movement compaired to the last two months', '2025-08-26 16:13:25.813', 10605, 3687, 59),
(NULL, 'still trying to push them to stock our products ', '2025-08-26 16:17:13.136', 10605, 3688, 28),
(NULL, 'placed an order for 12 vapes', '2025-08-26 16:25:28.259', 10605, 3689, 23),
(NULL, 'well stocked ', '2025-08-26 16:25:38.629', 10605, 3690, 28),
(NULL, 'waiting for the vapes ordered', '2025-08-26 16:32:09.113', 10605, 3691, 59),
(NULL, 'still haven\'t check with owner', '2025-08-26 16:33:13.572', 10605, 3692, 124),
(NULL, 'They have stocks ', '2025-08-26 17:04:00.500', 10605, 3693, 28),
(NULL, '*they haven\'t sold yet the 10pcs', '2025-08-26 17:03:01.114', 10605, 3694, 7),
(NULL, 'they have 49 PCs of woosh vapes in total. well stocked ', '2025-08-26 17:06:45.946', 10605, 3695, 23),
(NULL, 'will make a new order starting next month', '2025-08-26 17:23:06.187', 10605, 3696, 59),
(NULL, 'Movement is good..sold 6 today can do 4 everyday', '2025-08-26 17:42:01.502', 10605, 3697, 5),
(NULL, '*still have stock ', '2025-08-26 17:46:25.823', 10605, 3698, 7),
(NULL, 'Manager is out supervisor said manager will let me know if he wants to order or not', '2025-08-26 18:01:27.972', 10605, 3699, 124),
(NULL, 'test', '2025-08-27 07:39:40.005', 10733, 3700, 94),
(NULL, 'the outlet has been supplied with fresh fermented and longlife products', '2025-09-03 07:43:10.901', 10728, 3701, 178),
(NULL, 'delivery done', '2025-09-03 13:01:33.796', 10727, 3702, 178);

-- --------------------------------------------------------

--
-- Table structure for table `hr_calendar_tasks`
--

CREATE TABLE `hr_calendar_tasks` (
  `id` int(11) NOT NULL,
  `date` date NOT NULL,
  `title` varchar(255) NOT NULL DEFAULT '',
  `description` text DEFAULT NULL,
  `status` enum('Pending','In Progress','Completed') DEFAULT 'Pending',
  `assigned_to` varchar(100) DEFAULT NULL,
  `text` varchar(255) NOT NULL,
  `recurrence_type` enum('none','daily','weekly','monthly') DEFAULT 'none',
  `recurrence_end` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `hr_calendar_tasks`
--

INSERT INTO `hr_calendar_tasks` (`id`, `date`, `title`, `description`, `status`, `assigned_to`, `text`, `recurrence_type`, `recurrence_end`, `created_at`, `updated_at`) VALUES
(1, '2025-07-23', 'title', 'tska here', 'Pending', 'Benjamin Okwamas Test', 'nn', 'none', NULL, '2025-07-10 14:55:40', '2025-07-22 16:04:11'),
(13, '2025-07-19', 'title', 'nnmm', 'Completed', 'Benjamin Okwamas Test', '', 'none', NULL, '2025-07-19 10:04:02', '2025-07-19 10:07:52'),
(14, '2025-07-22', 'testing', '', 'Pending', NULL, '', 'none', NULL, '2025-07-24 08:20:08', '2025-07-24 08:20:08'),
(15, '2025-07-29', 'test task', '', 'Pending', NULL, '', 'none', NULL, '2025-07-28 09:34:54', '2025-07-28 09:34:54'),
(16, '2025-08-08', 'dd', 'ss', 'Pending', 'Benjamin Okwamas Test', '', 'none', NULL, '2025-08-08 00:53:18', '2025-08-08 00:53:18'),
(17, '2025-08-09', 'Tes', '', 'Pending', NULL, '', 'none', NULL, '2025-08-09 06:40:44', '2025-08-09 06:40:44'),
(18, '2025-08-20', 'warning', 'testimn', 'Pending', 'Benjamin Okwamas Test', '', 'none', NULL, '2025-08-19 10:37:00', '2025-08-19 10:37:00'),
(19, '2025-08-19', 'test', 'ss', 'In Progress', 'Benjamin Okwamas Test, CHARLES LUKANIA', '', 'none', NULL, '2025-08-19 20:49:08', '2025-08-19 20:49:08');

-- --------------------------------------------------------

--
-- Table structure for table `inventory_receipts`
--

CREATE TABLE `inventory_receipts` (
  `id` int(11) NOT NULL,
  `purchase_order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `received_quantity` int(11) NOT NULL,
  `received_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `received_by` int(11) NOT NULL DEFAULT 1,
  `unit_cost` decimal(10,2) NOT NULL DEFAULT 0.00,
  `total_cost` decimal(15,2) NOT NULL DEFAULT 0.00,
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `inventory_receipts`
--

INSERT INTO `inventory_receipts` (`id`, `purchase_order_id`, `product_id`, `store_id`, `received_quantity`, `received_at`, `received_by`, `unit_cost`, `total_cost`, `notes`) VALUES
(1, 3, 1, 2, 3, '2025-07-06 09:52:07', 1, 800.00, 2400.00, ''),
(2, 3, 2, 2, 4, '2025-07-06 09:52:07', 1, 15.00, 60.00, ''),
(4, 4, 10, 1, 1, '2025-07-06 14:48:46', 1, 200.00, 200.00, ''),
(5, 5, 7, 1, 12, '2025-07-06 15:05:25', 1, 309.99, 3719.88, ''),
(7, 6, 10, 1, 10, '2025-07-07 18:00:58', 1, 200.00, 2000.00, ''),
(8, 7, 6, 2, 1, '2025-07-07 18:13:23', 1, 4.00, 4.00, ''),
(9, 8, 4, 1, 2, '2025-07-12 07:00:07', 1, 300.00, 600.00, ''),
(11, 9, 6, 1, 1, '2025-07-14 07:55:09', 1, 299.98, 299.98, ''),
(12, 10, 6, 1, 10, '2025-07-14 07:58:07', 1, 200.00, 2000.00, ''),
(13, 11, 7, 1, 10, '2025-07-22 09:31:32', 1, 300.00, 3000.00, ''),
(14, 12, 5, 1, 1, '2025-07-28 10:26:51', 1, 200.00, 200.00, ''),
(15, 14, 34, 4, 13, '2025-08-09 09:01:51', 1, 300.00, 3900.00, ''),
(16, 18, 26, 1, 1, '2025-08-09 10:21:43', 1, 300.00, 300.00, ''),
(17, 19, 18, 3, 1, '2025-08-19 06:48:11', 1, 200.00, 200.00, '');

-- --------------------------------------------------------

--
-- Table structure for table `inventory_transactions`
--

CREATE TABLE `inventory_transactions` (
  `id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `amount_in` decimal(12,2) DEFAULT 0.00,
  `amount_out` decimal(12,2) DEFAULT 0.00,
  `balance` decimal(12,2) DEFAULT 0.00,
  `date_received` datetime NOT NULL,
  `store_id` int(11) NOT NULL,
  `unit_cost` decimal(11,2) NOT NULL,
  `total_cost` decimal(11,2) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `inventory_transactions`
--

INSERT INTO `inventory_transactions` (`id`, `product_id`, `reference`, `amount_in`, `amount_out`, `balance`, `date_received`, `store_id`, `unit_cost`, `total_cost`, `staff_id`, `created_at`) VALUES
(20, 21, 'Opening Balance', 348.00, 0.00, 348.00, '2025-08-03 11:45:12', 1, 0.00, 0.00, 1, '2025-08-03 07:45:12'),
(21, 22, 'Opening Balance', 421.00, 0.00, 421.00, '2025-08-03 12:03:32', 1, 0.00, 0.00, 1, '2025-08-03 08:03:32'),
(22, 25, 'Opening Balance', 826.00, 0.00, 826.00, '2025-08-03 12:03:32', 1, 0.00, 0.00, 1, '2025-08-03 08:03:32'),
(23, 23, 'Opening Balance', 740.00, 0.00, 740.00, '2025-08-03 12:03:33', 1, 0.00, 0.00, 1, '2025-08-03 08:03:33'),
(24, 24, 'Opening Balance', 778.00, 0.00, 778.00, '2025-08-03 12:03:33', 1, 0.00, 0.00, 1, '2025-08-03 08:03:33'),
(25, 22, 'Opening Balance', 6400.00, 0.00, 6400.00, '2025-08-03 12:06:07', 2, 0.00, 0.00, 1, '2025-08-03 08:06:07'),
(26, 21, 'Opening Balance', 14400.00, 0.00, 14400.00, '2025-08-03 12:06:07', 2, 0.00, 0.00, 1, '2025-08-03 08:06:07'),
(27, 25, 'Opening Balance', 10800.00, 0.00, 10800.00, '2025-08-03 12:06:07', 2, 0.00, 0.00, 1, '2025-08-03 08:06:07'),
(28, 23, 'Opening Balance', 11200.00, 0.00, 11200.00, '2025-08-03 12:06:07', 2, 0.00, 0.00, 1, '2025-08-03 08:06:07'),
(29, 24, 'Opening Balance', 9200.00, 0.00, 9200.00, '2025-08-03 12:06:07', 2, 0.00, 0.00, 1, '2025-08-03 08:06:07'),
(30, 27, 'Opening Balance', 768.00, 0.00, 768.00, '2025-08-03 12:14:07', 1, 0.00, 0.00, 1, '2025-08-03 08:14:07'),
(31, 26, 'Opening Balance', 274.00, 0.00, 274.00, '2025-08-03 12:14:07', 1, 0.00, 0.00, 1, '2025-08-03 08:14:07'),
(32, 30, 'Opening Balance', 1076.00, 0.00, 1076.00, '2025-08-03 12:14:07', 1, 0.00, 0.00, 1, '2025-08-03 08:14:07'),
(33, 28, 'Opening Balance', 904.00, 0.00, 904.00, '2025-08-03 12:14:07', 1, 0.00, 0.00, 1, '2025-08-03 08:14:07'),
(34, 29, 'Opening Balance', 359.00, 0.00, 359.00, '2025-08-03 12:14:07', 1, 0.00, 0.00, 1, '2025-08-03 08:14:07'),
(35, 27, 'Opening Balance', 3600.00, 0.00, 3600.00, '2025-08-03 12:15:23', 2, 0.00, 0.00, 1, '2025-08-03 08:15:23'),
(36, 26, 'Opening Balance', 13200.00, 0.00, 13200.00, '2025-08-03 12:15:23', 2, 0.00, 0.00, 1, '2025-08-03 08:15:23'),
(37, 30, 'Opening Balance', 4000.00, 0.00, 4000.00, '2025-08-03 12:15:23', 2, 0.00, 0.00, 1, '2025-08-03 08:15:23'),
(38, 28, 'Opening Balance', 4000.00, 0.00, 4000.00, '2025-08-03 12:15:23', 2, 0.00, 0.00, 1, '2025-08-03 08:15:23'),
(39, 29, 'Opening Balance', 6400.00, 0.00, 6400.00, '2025-08-03 12:15:23', 2, 0.00, 0.00, 1, '2025-08-03 08:15:23'),
(40, 7, 'Opening Balance', 151.00, 0.00, 151.00, '2025-08-03 12:58:50', 1, 0.00, 0.00, 1, '2025-08-03 08:58:50'),
(41, 11, 'Opening Balance', 103.00, 0.00, 103.00, '2025-08-03 12:58:51', 1, 0.00, 0.00, 1, '2025-08-03 08:58:51'),
(42, 1, 'Opening Balance', 137.00, 0.00, 137.00, '2025-08-03 12:58:51', 1, 0.00, 0.00, 1, '2025-08-03 08:58:51'),
(43, 8, 'Opening Balance', 242.00, 0.00, 242.00, '2025-08-03 12:58:51', 1, 0.00, 0.00, 1, '2025-08-03 08:58:51'),
(44, 7, 'Opening Balance', 600.00, 0.00, 600.00, '2025-08-03 13:01:00', 2, 0.00, 0.00, 1, '2025-08-03 09:01:00'),
(45, 11, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:00', 2, 0.00, 0.00, 1, '2025-08-03 09:01:00'),
(46, 10, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:01', 2, 0.00, 0.00, 1, '2025-08-03 09:01:01'),
(47, 1, 'Opening Balance', 900.00, 0.00, 900.00, '2025-08-03 13:01:01', 2, 0.00, 0.00, 1, '2025-08-03 09:01:01'),
(48, 3, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:01', 2, 0.00, 0.00, 1, '2025-08-03 09:01:01'),
(49, 8, 'Opening Balance', 1200.00, 0.00, 1200.00, '2025-08-03 13:01:01', 2, 0.00, 0.00, 1, '2025-08-03 09:01:01'),
(50, 9, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:01', 2, 0.00, 0.00, 1, '2025-08-03 09:01:01'),
(51, 10, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:23', 1, 0.00, 0.00, 1, '2025-08-03 09:01:23'),
(52, 3, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:23', 1, 0.00, 0.00, 1, '2025-08-03 09:01:23'),
(53, 9, 'Opening Balance', 0.00, 0.00, 0.00, '2025-08-03 13:01:23', 1, 0.00, 0.00, 1, '2025-08-03 09:01:23'),
(54, 6, 'Opening Balance', 2.00, 0.00, 2.00, '2025-08-04 06:40:08', 1, 0.00, 0.00, 1, '2025-08-04 02:40:08'),
(55, 16, 'Opening Balance', 8.00, 0.00, 8.00, '2025-08-04 06:40:09', 1, 0.00, 0.00, 1, '2025-08-04 02:40:09'),
(56, 4, 'Opening Balance', 5.00, 0.00, 5.00, '2025-08-04 06:40:09', 1, 0.00, 0.00, 1, '2025-08-04 02:40:09'),
(57, 12, 'Opening Balance', 1.00, 0.00, 1.00, '2025-08-04 06:40:10', 1, 0.00, 0.00, 1, '2025-08-04 02:40:10'),
(58, 2, 'Opening Balance', 2.00, 0.00, 2.00, '2025-08-04 06:40:11', 1, 0.00, 0.00, 1, '2025-08-04 02:40:11'),
(59, 40, 'Opening Balance', 10.00, 0.00, 10.00, '2025-08-04 07:10:32', 1, 0.00, 0.00, 1, '2025-08-04 03:10:32'),
(60, 32, 'Opening Balance', 21.00, 0.00, 21.00, '2025-08-04 07:10:32', 1, 0.00, 0.00, 1, '2025-08-04 03:10:32'),
(61, 36, 'Opening Balance', 2.00, 0.00, 2.00, '2025-08-04 07:10:33', 1, 0.00, 0.00, 1, '2025-08-04 03:10:33'),
(62, 37, 'Opening Balance', 9.00, 0.00, 9.00, '2025-08-04 07:10:34', 1, 0.00, 0.00, 1, '2025-08-04 03:10:34'),
(63, 41, 'Opening Balance', 1.00, 0.00, 1.00, '2025-08-04 07:10:34', 1, 0.00, 0.00, 1, '2025-08-04 03:10:34'),
(64, 38, 'Opening Balance', 4.00, 0.00, 4.00, '2025-08-04 07:10:35', 1, 0.00, 0.00, 1, '2025-08-04 03:10:35'),
(65, 31, 'Opening Balance', 34.00, 0.00, 34.00, '2025-08-04 07:10:36', 1, 0.00, 0.00, 1, '2025-08-04 03:10:36'),
(66, 33, 'Opening Balance', 51.00, 0.00, 51.00, '2025-08-04 07:10:37', 1, 0.00, 0.00, 1, '2025-08-04 03:10:37'),
(67, 35, 'Opening Balance', 18.00, 0.00, 18.00, '2025-08-04 07:10:37', 1, 0.00, 0.00, 1, '2025-08-04 03:10:37'),
(68, 43, 'Manual Stock Update', 2.00, 0.00, 2.00, '2025-08-04 07:58:23', 1, 0.00, 0.00, 1, '2025-08-04 03:58:23'),
(69, 34, 'PO-000014', 13.00, 0.00, 13.00, '2025-08-09 11:01:52', 4, 300.00, 3900.00, 1, '2025-08-09 09:01:52'),
(70, 26, 'PO-000018', 1.00, 0.00, 275.00, '2025-08-09 12:21:43', 1, 300.00, 300.00, 1, '2025-08-09 10:21:43'),
(71, 7, 'CNR-1754881290610-HNUJ', 3.00, 0.00, 1513333.00, '2025-08-11 05:01:30', 1, 45.00, 135.00, 1, '2025-08-11 03:01:30'),
(72, 7, 'CNR-1754881328896-6EG3', 3.00, 0.00, 15133333.00, '2025-08-11 05:02:08', 1, 45.00, 135.00, 1, '2025-08-11 03:02:08'),
(73, 7, 'CNR-1754881581323-PDL5', 3.00, 0.00, 151333333.00, '2025-08-11 05:06:20', 1, 45.00, 135.00, 1, '2025-08-11 03:06:20'),
(74, 7, 'CNR-1754881646463-S33W', 3.00, 0.00, 3003.00, '2025-08-11 05:07:25', 1, 45.00, 135.00, 1, '2025-08-11 03:07:25'),
(75, 7, 'CNR-1754881672986-ACTK', 3.00, 0.00, 30033.00, '2025-08-11 05:07:52', 1, 45.00, 135.00, 1, '2025-08-11 03:07:52'),
(76, 7, 'CNR-1754881850895-L2GQ', 3.00, 0.00, 303.00, '2025-08-11 05:10:50', 1, 45.00, 135.00, 1, '2025-08-11 03:10:50'),
(77, 7, 'CNR-1754881879000-YCBJ', 3.00, 0.00, 306.00, '2025-08-11 05:11:18', 1, 45.00, 135.00, 1, '2025-08-11 03:11:18'),
(78, 7, 'CNR-1754882373987-YQGX', 3.00, 0.00, 309.00, '2025-08-11 05:19:33', 1, 45.00, 135.00, 1, '2025-08-11 03:19:33'),
(79, 7, 'CNR-1754882646777-UU4M', 3.00, 0.00, 603.00, '2025-08-11 05:24:06', 1, 45.00, 135.00, 1, '2025-08-11 03:24:06'),
(80, 7, 'CNR-1754883925869-CL2F', 3.00, 0.00, 606.00, '2025-08-11 05:45:25', 1, 45.00, 135.00, 1, '2025-08-11 03:45:25'),
(81, 7, 'CNR-1754884109249-H1LB', 3.00, 0.00, 609.00, '2025-08-11 05:48:28', 1, 45.00, 135.00, 1, '2025-08-11 03:48:28'),
(82, 7, 'CNR-1754884200166-MDFI', 3.00, 0.00, 612.00, '2025-08-11 05:49:59', 1, 45.00, 135.00, 1, '2025-08-11 03:49:59'),
(83, 7, 'Return to stock from cancelled order SO-2025-0004', 2.00, 0.00, 614.00, '2025-08-11 14:43:31', 1, 0.00, 0.00, 1, '2025-08-11 12:43:31'),
(84, 7, 'Return to stock from cancelled order SO-2025-0004', 2.00, 0.00, 616.00, '2025-08-11 14:48:38', 1, 0.00, 0.00, 1, '2025-08-11 12:48:38'),
(87, 7, 'Return to stock from cancelled order SO-2025-0004', 2.00, 0.00, 618.00, '2025-08-11 15:09:39', 1, 0.00, 0.00, 1, '2025-08-11 13:09:39'),
(88, 6, 'n', 0.00, 1.00, 1.00, '2025-08-19 00:00:00', 1, 0.00, 0.00, 1, '2025-08-19 06:20:23'),
(89, 6, 'n', 1.00, 0.00, 1.00, '2025-08-19 00:00:00', 2, 0.00, 0.00, 1, '2025-08-19 06:20:23'),
(90, 18, 'PO-000019', 1.00, 0.00, 1.00, '2025-08-19 08:48:11', 3, 200.00, 200.00, 1, '2025-08-19 06:48:11');

-- --------------------------------------------------------

--
-- Table structure for table `inventory_transfers`
--

CREATE TABLE `inventory_transfers` (
  `id` int(11) NOT NULL,
  `from_store_id` int(11) NOT NULL,
  `to_store_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` decimal(12,2) NOT NULL,
  `transfer_date` datetime NOT NULL,
  `staff_id` int(11) NOT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `inventory_transfers`
--

INSERT INTO `inventory_transfers` (`id`, `from_store_id`, `to_store_id`, `product_id`, `quantity`, `transfer_date`, `staff_id`, `reference`, `notes`, `created_at`) VALUES
(1, 1, 2, 9, 7.00, '2025-07-14 00:00:00', 1, 'b', '', '2025-07-14 09:38:49'),
(2, 1, 2, 9, 7000.00, '2025-07-14 00:00:00', 1, '', '', '2025-07-14 09:39:00'),
(3, 2, 4, 8, 2.00, '2025-07-14 00:00:00', 1, '', 'ff', '2025-07-14 09:42:43'),
(4, 2, 4, 9, 5.00, '2025-07-14 00:00:00', 1, '', 'ff', '2025-07-14 09:42:43'),
(5, 1, 2, 7, 1.00, '2025-07-14 00:00:00', 1, '', '', '2025-07-14 09:45:44'),
(6, 1, 2, 6, 1.00, '2025-07-14 00:00:00', 1, 'test', 'testing', '2025-07-14 10:07:48'),
(7, 1, 2, 6, 1.00, '2025-08-19 00:00:00', 1, 'n', 'n', '2025-08-19 06:20:23');

-- --------------------------------------------------------

--
-- Table structure for table `journal_entries`
--

CREATE TABLE `journal_entries` (
  `id` int(11) NOT NULL,
  `entry_number` varchar(20) NOT NULL,
  `entry_date` date NOT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `total_debit` decimal(15,2) DEFAULT 0.00,
  `total_credit` decimal(15,2) DEFAULT 0.00,
  `status` enum('draft','posted','cancelled') DEFAULT 'draft',
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `journal_entries`
--

INSERT INTO `journal_entries` (`id`, `entry_number`, `entry_date`, `reference`, `description`, `total_debit`, `total_credit`, `status`, `created_by`, `created_at`, `updated_at`) VALUES
(28, 'JE-EQ-49-17519944954', '2025-07-08', '', 'Equity entry', 700.00, 700.00, 'posted', 1, '2025-07-08 15:08:14', '2025-07-08 15:08:14'),
(29, 'JE-DEP-5-17519949253', '2025-07-08', 'Depreciation for asset 5', 'Depreciation for asset 5', 700.00, 700.00, 'posted', 1, '2025-07-08 15:15:24', '2025-07-08 15:15:24'),
(30, 'JE-SALES-12-17519961', '2025-07-08', 'INV-3-1751996124894', 'Sales invoice INV-3-1751996124894', 665.50, 665.50, 'posted', 1, '2025-07-08 15:35:24', '2025-07-08 15:35:24'),
(31, 'JE-COGS-12-175199612', '2025-07-08', 'INV-3-1751996124894', 'Cost of goods sold for INV-3-1751996124894', 330.00, 330.00, 'posted', 1, '2025-07-08 15:35:24', '2025-07-08 15:35:24'),
(32, 'JE-EXP-81-1751996155', '2025-07-08', '', 'Expense posted', 200.00, 200.00, 'posted', 1, '2025-07-08 15:35:54', '2025-07-08 15:35:54'),
(33, 'JE-SALES-13-17523093', '2025-07-12', 'INV-2-1752309325399', 'Sales invoice INV-2-1752309325399', 93.50, 93.50, 'posted', 1, '2025-07-12 06:35:25', '2025-07-12 06:35:25'),
(34, 'JE-COGS-13-175230932', '2025-07-12', 'INV-2-1752309325399', 'Cost of goods sold for INV-2-1752309325399', 45.00, 45.00, 'posted', 1, '2025-07-12 06:35:25', '2025-07-12 06:35:25'),
(35, 'JE-PO-8-175231080915', '2025-07-12', 'PO-000008', 'Goods received for PO PO-000008', 600.00, 600.00, 'posted', 1, '2025-07-12 07:00:08', '2025-07-12 07:00:08'),
(36, 'JE-EQ-50-17523125487', '2025-07-12', '', 'nn', 900.00, 900.00, 'posted', 1, '2025-07-12 07:29:08', '2025-07-12 07:29:08'),
(37, 'JE-EQ-49-17523126314', '2025-07-12', '', 'cc', 300.00, 300.00, 'posted', 1, '2025-07-12 07:30:30', '2025-07-12 07:30:30'),
(38, 'JE-EQ-49-17523134906', '2025-07-12', '', 'Equity entry', 700.00, 700.00, 'posted', 1, '2025-07-12 07:44:50', '2025-07-12 07:44:50'),
(39, 'JE-EQ-49-17523147705', '2025-07-12', '', 'd', 300.00, 300.00, 'posted', 1, '2025-07-12 08:06:09', '2025-07-12 08:06:09'),
(40, 'JE-DEP-1-17523149812', '2025-07-12', 'Depreciation for asset 1', 'Depreciation for asset 1', 200.00, 200.00, 'posted', 1, '2025-07-12 08:09:40', '2025-07-12 08:09:40'),
(41, 'JE-DEP-1-17523159745', '2025-07-11', 'Depreciation for asset 1', 'Depreciation for asset 1', 200.00, 200.00, 'posted', 1, '2025-07-12 08:26:13', '2025-07-12 08:26:13'),
(42, 'JE-DEP-1-17523171545', '2025-07-12', 'Depreciation for asset 1', 'Depreciation for asset 1', 700.00, 700.00, 'posted', 1, '2025-07-12 08:45:54', '2025-07-12 08:45:54'),
(43, 'JE-DEP-4-17523177493', '2025-07-12', 'Depreciation for asset 4', 'Depreciation for asset 4', 200.00, 200.00, 'posted', 1, '2025-07-12 08:55:48', '2025-07-12 08:55:48'),
(44, 'JE-RCP-2-17523204574', '2025-07-12', 'RCP-6', 'Customer payment - check', 210.00, 210.00, '', 1, '2025-07-12 09:40:56', '2025-07-12 09:41:07'),
(45, 'JE-SALES-14-17523208', '2025-07-12', 'INV-2-1752320810962', 'Sales invoice INV-2-1752320810962', 60.50, 60.50, 'posted', 1, '2025-07-12 09:46:51', '2025-07-12 09:46:51'),
(46, 'JE-COGS-14-175232081', '2025-07-12', 'INV-2-1752320810962', 'Cost of goods sold for INV-2-1752320810962', 30.00, 30.00, 'posted', 1, '2025-07-12 09:46:51', '2025-07-12 09:46:51'),
(47, 'JE-SALES-15-17523211', '2025-07-12', 'INV-2-1752321159077', 'Sales invoice INV-2-1752321159077', 13200.00, 13200.00, 'posted', 1, '2025-07-12 09:52:39', '2025-07-12 09:52:39'),
(48, 'JE-COGS-15-175232116', '2025-07-12', 'INV-2-1752321159077', 'Cost of goods sold for INV-2-1752321159077', 8000.00, 8000.00, 'posted', 1, '2025-07-12 09:52:39', '2025-07-12 09:52:39'),
(49, 'JE-RCP-2-17523220547', '2025-07-12', 'RCP-7', 'Customer payment - check', 100.00, 100.00, '', 1, '2025-07-12 10:07:34', '2025-07-12 10:07:40'),
(50, 'JE-OB-23-17523235742', '2025-07-01', 'Opening Balance', 'Opening balance for M-pesa', 30000.00, 30000.00, 'posted', 1, '2025-07-12 10:32:53', '2025-07-12 10:32:53'),
(51, 'JE-OB-22-17523239682', '2025-07-01', 'Opening Balance', 'Opening balance for DTB USD', 10000.00, 10000.00, 'posted', 1, '2025-07-12 10:39:27', '2025-07-12 10:39:27'),
(52, 'JE-PAYROLL-3-1752344', '2025-07-12', 'PAYROLL-3', 'Payroll for staff 3', 34036.65, 34036.65, 'posted', 1, '2025-07-12 16:27:06', '2025-07-12 16:27:06'),
(53, 'JE-PAYROLL-2-1752348', '2025-07-12', 'PAYROLL-2', 'Payroll for staff 2', 37536.65, 37536.65, 'posted', 1, '2025-07-12 17:30:17', '2025-07-12 17:30:17'),
(54, 'JE-PAYROLL-3-1752348', '2025-07-13', 'PAYROLL-3', 'Payroll for staff 3', 34036.65, 34036.65, 'posted', 1, '2025-07-12 17:35:28', '2025-07-12 17:35:28'),
(55, 'JE-SALES-16-17523975', '2025-07-13', 'INV-2-1752397570019', 'Sales invoice INV-2-1752397570019', 148.50, 148.50, 'posted', 1, '2025-07-13 07:06:07', '2025-07-13 07:06:07'),
(56, 'JE-COGS-16-175239757', '2025-07-13', 'INV-2-1752397570019', 'Cost of goods sold for INV-2-1752397570019', 75.00, 75.00, 'posted', 1, '2025-07-13 07:06:08', '2025-07-13 07:06:08'),
(57, 'JE-RCP-2-17523977888', '2025-07-13', 'RCP-8', 'Customer payment - cash', 400.00, 400.00, '', 1, '2025-07-13 07:09:46', '2025-07-13 07:09:59'),
(58, 'JE-RCP-2-17523994395', '2025-07-13', 'RCP-9', 'Customer payment - bank_transfer', 40.00, 40.00, '', 1, '2025-07-13 07:37:16', '2025-07-13 07:59:58'),
(59, 'JE-RCP-2-17524000983', '2025-07-13', 'RCP-10', 'Customer payment - bank_transfer', 200.00, 200.00, '', 1, '2025-07-13 07:48:15', '2025-07-13 07:59:18'),
(60, 'JE-RCP-2-17524018917', '2025-07-13', 'RCP-11', 'Customer payment - bank_transfer', 30.50, 30.50, 'posted', 1, '2025-07-13 08:18:09', '2025-07-13 08:18:09'),
(61, 'JE-PAY-3-17524033001', '2025-07-13', 'PAY-8', 'Supplier payment', 200.00, 200.00, 'posted', 1, '2025-07-13 08:41:37', '2025-07-13 08:41:37'),
(62, 'JE-PO-9-175248691177', '2025-07-14', 'PO-000009', 'Goods received for PO PO-000009', 299.98, 299.98, 'posted', 1, '2025-07-14 07:55:10', '2025-07-14 07:55:10'),
(63, 'JE-PO-10-17524870898', '2025-07-14', 'PO-000010', 'Goods received for PO PO-000010', 2000.00, 2000.00, 'posted', 1, '2025-07-14 07:58:08', '2025-07-14 07:58:08'),
(64, 'JE-SALES-21-17526494', '2025-07-16', 'INV-2-1752649457669', 'Sales invoice INV-2-1752649457669', 99.00, 99.00, 'posted', 1, '2025-07-16 05:04:20', '2025-07-16 05:04:20'),
(65, 'JE-COGS-21-175264946', '2025-07-16', 'INV-2-1752649457669', 'Cost of goods sold for INV-2-1752649457669', 55.00, 55.00, 'posted', 1, '2025-07-16 05:04:22', '2025-07-16 05:04:22'),
(66, 'JE-RCP-2-17527558713', '2025-07-16', 'RCP-15', 'Customer payment - cash', 99.00, 99.00, 'posted', 1, '2025-07-17 10:37:50', '2025-07-17 10:37:50'),
(67, 'JE-PO-11-17531838959', '2025-07-22', 'PO-000011', 'Goods received for PO PO-000011', 3000.00, 3000.00, 'posted', 1, '2025-07-22 09:31:34', '2025-07-22 09:31:34'),
(68, 'JE-EQ-49-17532791755', '2025-07-23', 'test1', 'test', 3000.00, 3000.00, 'posted', 1, '2025-07-23 11:59:34', '2025-07-23 11:59:34'),
(69, 'JE-EXP-110-175329011', '2025-07-23', 'test', 'test', 5000.00, 5000.00, 'posted', 1, '2025-07-23 15:01:56', '2025-07-23 15:01:56'),
(70, 'JE-PO-12-17537056151', '2025-07-28', 'PO-000012', 'Goods received for PO PO-000012', 200.00, 200.00, 'posted', 1, '2025-07-28 10:26:52', '2025-07-28 10:26:52'),
(71, 'JE-EXP-85-1753708715', '2025-07-28', 'test', 'desc', 2000.00, 2000.00, 'posted', 1, '2025-07-28 11:18:32', '2025-07-28 11:18:32'),
(72, 'JE-1753724689958-krv', '2025-07-28', 'ref 2', 'testing 2', 200.00, 200.00, 'posted', 1, '2025-07-28 15:44:49', '2025-07-28 15:44:49'),
(73, 'JE-SO-35-17539356484', '2025-07-27', 'SO-35', 'Sales order approved - SO-1753903474059', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:20:47', '2025-07-31 02:20:47'),
(74, 'JE-SO-35-17539358743', '2025-07-26', 'SO-35', 'Sales order approved - SO-1753903474059', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:24:33', '2025-07-31 02:24:33'),
(75, 'JE-SO-35-17539361749', '2025-07-25', 'SO-35', 'Sales order approved - SO-1753903474059', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:29:34', '2025-07-31 02:29:34'),
(76, 'JE-SO-33-17539366057', '2025-07-29', 'SO-33', 'Sales order approved - SO-1753900819864', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:36:45', '2025-07-31 02:36:45'),
(77, 'JE-SO-35-17539369246', '2025-07-24', 'SO-35', 'Sales order approved - SO-1753903474059', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:42:04', '2025-07-31 02:42:04'),
(78, 'JE-INV-34-1753937223', '2025-07-29', 'INV-34', 'Invoice created from order - SO-1753902731779', 2200.00, 2200.00, 'posted', 1, '2025-07-31 02:47:02', '2025-07-31 02:47:02'),
(79, 'JE-SO-43-17541414763', '2025-08-02', 'SO-43', 'Sales order approved - SO-2025-0002', 2200.00, 2200.00, 'posted', 1, '2025-08-02 11:31:15', '2025-08-02 11:31:15'),
(80, 'JE-SO-42-17541430060', '2025-08-02', 'SO-42', 'Sales order approved - SO-2025-0001', 11000.00, 11000.00, 'posted', 1, '2025-08-02 11:56:45', '2025-08-02 11:56:45'),
(81, 'JE-INV-48-1754269066', '2025-08-04', 'INV-48', 'Invoice created from order - SO-000007', 2200.00, 2200.00, 'posted', 1, '2025-08-03 22:57:43', '2025-08-03 22:57:43'),
(82, 'JE-INV-55-1754474609', '2025-08-04', 'INV-55', 'Invoice created from order - SO-2025-0001', 11000.00, 11000.00, 'posted', 1, '2025-08-06 10:03:26', '2025-08-06 10:03:26'),
(83, 'JE-INV-56-1754483154', '2025-08-06', 'INV-56', 'Invoice created from order - SO-2025-0001', 6600.00, 6600.00, 'posted', 1, '2025-08-06 12:25:52', '2025-08-06 12:25:52'),
(84, 'JE-INV-57-1754492311', '2025-08-06', 'INV-57', 'Invoice created from order - SO-2025-0001', 2200.00, 2200.00, 'posted', 1, '2025-08-06 14:58:29', '2025-08-06 14:58:29'),
(85, 'JE-INV-58-1754505982', '2025-08-06', 'INV-58', 'Invoice created from order - SO-2025-0001', 4400.00, 4400.00, 'posted', 1, '2025-08-06 18:46:21', '2025-08-06 18:46:21'),
(86, 'JE-INV-59-1754506672', '2025-08-06', 'INV-59', 'Invoice created from order - SO-2025-0001', 6600.00, 6600.00, 'posted', 1, '2025-08-06 18:57:52', '2025-08-06 18:57:52'),
(87, 'JE-RCP-10171-1754509', '2025-08-06', 'RCP-18', 'Customer payment - cash', 2000.00, 2000.00, 'posted', 1, '2025-08-06 19:39:18', '2025-08-06 19:39:18'),
(88, 'JE-RCP-10171-1754513', '2025-08-06', 'RCP-22', 'Customer payment - cash', 4.00, 4.00, 'posted', 1, '2025-08-06 20:50:55', '2025-08-06 20:50:55'),
(89, 'CN-1', '2025-08-07', 'CN-1754530076209', 'Credit Note CN-1754530076209 - test', 4000.00, 4000.00, 'posted', 0, '2025-08-07 01:28:07', '2025-08-07 01:28:07'),
(90, 'CN-2', '2025-08-07', 'CN-1754531048437', 'Credit Note CN-1754531048437 - n', 2000.00, 2000.00, 'posted', 0, '2025-08-07 01:50:15', '2025-08-07 01:50:15'),
(91, 'JE-INV-60-1754536153', '2025-08-07', 'INV-60', 'Invoice created from order - SO-2025-0001', 2200.00, 2200.00, 'posted', 1, '2025-08-07 03:09:13', '2025-08-07 03:09:13'),
(92, 'JE-INV-61-1754536211', '2025-08-07', 'INV-61', 'Invoice created from order - SO-2025-0001', 4400.00, 4400.00, 'posted', 1, '2025-08-07 03:10:11', '2025-08-07 03:10:11'),
(93, 'JE-EXP-81-1754537287', '2025-08-07', 'test', 'test', 1000.00, 1000.00, 'posted', 1, '2025-08-07 03:28:06', '2025-08-07 03:28:06'),
(94, 'JE-INV-65-1754624130', '2025-08-07', 'INV-65', 'Invoice created from order - SO-2025-0004', 2000.00, 2000.00, 'posted', 1, '2025-08-08 03:35:30', '2025-08-08 03:35:30'),
(95, 'JE-PO-14-17547301142', '2025-08-09', 'PO-000014', 'Goods received for PO PO-000014', 3900.00, 3900.00, 'posted', 1, '2025-08-09 09:01:53', '2025-08-09 09:01:53'),
(96, 'JE-PO-18-17547349048', '2025-08-09', 'PO-000018', 'Goods received for PO PO-000018', 300.00, 300.00, 'posted', 1, '2025-08-09 10:21:43', '2025-08-09 10:21:43'),
(97, 'JE-PAY-3-17547445936', '2025-08-09', 'PAY-3-1754744593126', 'Supplier payment', 4.00, 4.00, 'posted', 1, '2025-08-09 13:03:12', '2025-08-09 13:03:12'),
(98, 'JE-PAY-3-17547447479', '2025-08-09', 'PAY-3-1754744747384', 'Supplier payment', 100.00, 100.00, 'posted', 1, '2025-08-09 13:05:47', '2025-08-09 13:05:47'),
(99, 'JE-INV-70-1754758376', '2025-08-09', 'INV-70', 'Invoice created from order - SO-2025-0006', 6000.00, 6000.00, 'posted', 1, '2025-08-09 16:52:55', '2025-08-09 16:52:55'),
(100, 'JE-PAYROLL-1-1754822', '2025-08-10', 'PAYROLL-1', 'Payroll for staff 1', -140.60, -140.60, 'posted', 1, '2025-08-10 10:41:54', '2025-08-10 10:41:54'),
(101, 'JE-PAYROLL-2-1754822', '2025-08-10', 'PAYROLL-2', 'Payroll for staff 2', 37536.65, 37536.65, 'posted', 1, '2025-08-10 10:41:54', '2025-08-10 10:41:54'),
(102, 'JE-PAYROLL-3-1754822', '2025-08-10', 'PAYROLL-3', 'Payroll for staff 3', 34036.65, 34036.65, 'posted', 1, '2025-08-10 10:41:55', '2025-08-10 10:41:55'),
(103, 'JE-PAYROLL-4-1754822', '2025-08-10', 'PAYROLL-4', 'Payroll for staff 4', 37536.65, 37536.65, 'posted', 1, '2025-08-10 10:41:55', '2025-08-10 10:41:55'),
(104, 'JE-PAYROLL-5-1754822', '2025-08-10', 'PAYROLL-5', 'Payroll for staff 5', 26920.00, 26920.00, 'posted', 1, '2025-08-10 10:41:56', '2025-08-10 10:41:56'),
(105, 'JE-PAYROLL-6-1754822', '2025-08-10', 'PAYROLL-6', 'Payroll for staff 6', 30536.65, 30536.65, 'posted', 1, '2025-08-10 10:41:56', '2025-08-10 10:41:56'),
(106, 'JE-PAYROLL-7-1754822', '2025-08-10', 'PAYROLL-7', 'Payroll for staff 7', 34036.65, 34036.65, 'posted', 1, '2025-08-10 10:41:56', '2025-08-10 10:41:56'),
(107, 'JE-PAYROLL-8-1754822', '2025-08-10', 'PAYROLL-8', 'Payroll for staff 8', -150.00, -150.00, 'posted', 1, '2025-08-10 10:41:57', '2025-08-10 10:41:57'),
(108, 'JE-PAYROLL-9-1754822', '2025-08-10', 'PAYROLL-9', 'Payroll for staff 9', -150.00, -150.00, 'posted', 1, '2025-08-10 10:41:57', '2025-08-10 10:41:57'),
(109, 'JE-INV-64-1754826863', '2025-08-05', 'INV-64', 'Invoice created from order - SO-2025-0003', 6000.00, 6000.00, 'posted', 1, '2025-08-10 11:54:22', '2025-08-10 11:54:22'),
(110, 'JE-CN-7-175486028581', '2025-08-10', 'CN-10171-1754860285275', 'Credit note CN-10171-1754860285275', 2000.00, 2000.00, 'posted', 1, '2025-08-10 21:11:24', '2025-08-10 21:11:24'),
(111, 'JE-CN-8-175486076038', '2025-08-10', 'CN-10171-1754860759831', 'Credit note CN-10171-1754860759831', 4000.00, 4000.00, 'posted', 1, '2025-08-10 21:19:19', '2025-08-10 21:19:19'),
(112, 'JE-CN-9-175486081018', '2025-08-10', 'CN-10171-1754860809623', 'Credit note CN-10171-1754860809623', 2000.00, 2000.00, 'posted', 1, '2025-08-10 21:20:09', '2025-08-10 21:20:09'),
(113, 'JE-CN-10-17548608348', '2025-08-10', 'CN-10171-1754860834263', 'Credit note CN-10171-1754860834263', 2000.00, 2000.00, 'posted', 1, '2025-08-10 21:20:33', '2025-08-10 21:20:33'),
(114, 'JE-CN-11-17548616890', '2025-08-10', 'CN-2221-1754861688533', 'Credit note CN-2221-1754861688533', 6000.00, 6000.00, 'posted', 1, '2025-08-10 21:34:47', '2025-08-10 21:34:47'),
(115, 'JE-INV-71-1754988003', '2025-08-12', 'INV-71', 'Invoice created from order - SO-2025-0005', 2000.00, 2000.00, 'posted', 1, '2025-08-12 08:40:03', '2025-08-12 08:40:03'),
(116, 'JE-INV-72-1754988191', '2025-08-12', 'INV-72', 'Invoice created from order - SO-000015', 2000.00, 2000.00, 'posted', 1, '2025-08-12 08:43:10', '2025-08-12 08:43:10'),
(117, 'JE-INV-73-1755575720', '2025-08-19', 'INV-73', 'Invoice created from order - SO-2025-0005', 2000.00, 2000.00, 'posted', 1, '2025-08-19 03:55:19', '2025-08-19 03:55:19'),
(118, 'JE-RCP-2221-17555767', '2025-08-19', 'RCP-24', 'Customer payment - cash', 2000.00, 2000.00, 'posted', 1, '2025-08-19 04:12:08', '2025-08-19 04:12:08'),
(119, 'JE-CN-12-17555785505', '2025-08-19', 'CN-2221-1755578549613', 'Credit note CN-2221-1755578549613', 2000.00, 2000.00, 'posted', 1, '2025-08-19 04:42:29', '2025-08-19 04:42:29'),
(120, 'JE-INV-74-1755586052', '2025-08-19', 'INV-74', 'Invoice created from order - SO-000017', 387.93, 387.93, 'posted', 1, '2025-08-19 06:47:31', '2025-08-19 06:47:31'),
(121, 'JE-PO-19-17555860930', '2025-08-19', 'PO-000019', 'Goods received for PO PO-000019', 200.00, 200.00, 'posted', 1, '2025-08-19 06:48:12', '2025-08-19 06:48:12'),
(122, 'JE-INV-75-1755586478', '2025-08-19', 'INV-75', 'Invoice created from order - SO-000018', 450.00, 450.00, 'posted', 1, '2025-08-19 06:54:37', '2025-08-19 06:54:37'),
(123, 'JE-INV-76-1755596713', '2025-08-19', 'INV-76', 'Invoice created from order - SO-2025-0005', 3800.00, 3800.00, 'posted', 1, '2025-08-19 09:45:12', '2025-08-19 09:45:12'),
(124, 'JE-INV-77-1755597225', '2025-08-19', 'INV-77', 'Invoice created from order - SO-000019', 387.93, 387.93, 'posted', 1, '2025-08-19 09:53:45', '2025-08-19 09:53:45'),
(125, 'JE-INV-78-1755597421', '2025-08-19', 'INV-78', 'Invoice created from order - SO-000020', 450.00, 450.00, 'posted', 1, '2025-08-19 09:57:00', '2025-08-19 09:57:00'),
(126, 'JE-INV-87-1755865530', '2025-08-22', 'INV-87', 'Invoice created from order - SO-002026', 200.00, 200.00, 'posted', 1, '2025-08-22 12:25:29', '2025-08-22 12:25:29'),
(127, 'JE-INV-88-1755870331', '2025-08-22', 'INV-88', 'Invoice created from order - SO-002026', 232.00, 232.00, 'posted', 1, '2025-08-22 13:45:30', '2025-08-22 13:45:30'),
(128, 'JE-INV-95-1755872186', '2025-08-22', 'INV-95', 'Invoice created from order - SO-002032', 2320.00, 2320.00, 'posted', 1, '2025-08-22 14:16:26', '2025-08-22 14:16:26'),
(129, 'JE-INV-96-1756122883', '2025-08-25', 'INV-96', 'Invoice created from order - SO-2025-0005', 9600.00, 9600.00, 'posted', 1, '2025-08-25 11:54:43', '2025-08-25 11:54:43'),
(130, 'JE-INV-97-1756123321', '2025-08-25', 'INV-97', 'Invoice created from order - SO-2025-0005', 10800.00, 10800.00, 'posted', 1, '2025-08-25 12:02:01', '2025-08-25 12:02:01'),
(131, 'JE-INV-98-1756126138', '2025-08-25', 'INV-98', 'Invoice created from order - SO-2025-0005', 1100.00, 1100.00, 'posted', 1, '2025-08-25 12:48:56', '2025-08-25 12:48:56');

-- --------------------------------------------------------

--
-- Table structure for table `journal_entry_lines`
--

CREATE TABLE `journal_entry_lines` (
  `id` int(11) NOT NULL,
  `journal_entry_id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `debit_amount` decimal(15,2) DEFAULT 0.00,
  `credit_amount` decimal(15,2) DEFAULT 0.00,
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `journal_entry_lines`
--

INSERT INTO `journal_entry_lines` (`id`, `journal_entry_id`, `account_id`, `debit_amount`, `credit_amount`, `description`) VALUES
(55, 28, 49, 0.00, 700.00, 'Equity funding'),
(56, 29, 139, 700.00, 0.00, 'Depreciation'),
(57, 29, 139, 0.00, 700.00, 'Depreciation'),
(58, 30, 12, 665.50, 0.00, 'Invoice INV-3-1751996124894'),
(59, 30, 53, 0.00, 605.00, 'Sales revenue - INV-3-1751996124894'),
(60, 30, 35, 0.00, 60.50, 'Sales tax - INV-3-1751996124894'),
(61, 31, 63, 330.00, 0.00, 'COGS - INV-3-1751996124894'),
(62, 31, 10, 0.00, 330.00, 'Inventory reduction - INV-3-1751996124894'),
(63, 32, 81, 200.00, 0.00, 'Expense'),
(64, 32, 32, 0.00, 200.00, 'Accrued expense'),
(65, 33, 12, 93.50, 0.00, 'Invoice INV-2-1752309325399'),
(66, 33, 53, 0.00, 85.00, 'Sales revenue - INV-2-1752309325399'),
(67, 33, 35, 0.00, 8.50, 'Sales tax - INV-2-1752309325399'),
(68, 34, 63, 45.00, 0.00, 'COGS - INV-2-1752309325399'),
(69, 34, 10, 0.00, 45.00, 'Inventory reduction - INV-2-1752309325399'),
(70, 35, 10, 600.00, 0.00, 'Goods received for PO PO-000008'),
(71, 35, 30, 0.00, 600.00, 'Goods received for PO PO-000008'),
(72, 36, 50, 0.00, 900.00, 'nn'),
(73, 37, 49, 0.00, 300.00, 'cc'),
(74, 38, 49, 0.00, 700.00, 'Equity funding'),
(75, 39, 49, 0.00, 300.00, 'd'),
(82, 43, 136, 200.00, 0.00, 'Depreciation'),
(83, 43, 139, 0.00, 200.00, 'Depreciation'),
(84, 44, 23, 210.00, 0.00, 'Customer payment received'),
(85, 44, 140, 0.00, 210.00, 'Customer payment received'),
(86, 45, 12, 60.50, 0.00, 'Invoice INV-2-1752320810962'),
(87, 45, 53, 0.00, 55.00, 'Sales revenue - INV-2-1752320810962'),
(88, 45, 35, 0.00, 5.50, 'Sales tax - INV-2-1752320810962'),
(89, 46, 63, 30.00, 0.00, 'COGS - INV-2-1752320810962'),
(90, 46, 10, 0.00, 30.00, 'Inventory reduction - INV-2-1752320810962'),
(91, 47, 140, 13200.00, 0.00, 'Invoice INV-2-1752321159077'),
(92, 47, 53, 0.00, 12000.00, 'Sales revenue - INV-2-1752321159077'),
(93, 47, 35, 0.00, 1200.00, 'Sales tax - INV-2-1752321159077'),
(94, 48, 63, 8000.00, 0.00, 'COGS - INV-2-1752321159077'),
(95, 48, 10, 0.00, 8000.00, 'Inventory reduction - INV-2-1752321159077'),
(96, 49, 23, 100.00, 0.00, 'Customer payment received'),
(97, 49, 140, 0.00, 100.00, 'Customer payment received'),
(98, 50, 23, 30000.00, 0.00, 'Opening balance'),
(99, 50, 1, 0.00, 30000.00, 'Opening balance'),
(100, 51, 22, 10000.00, 0.00, 'Opening balance'),
(101, 51, 1, 0.00, 10000.00, 'Opening balance'),
(102, 52, 38, 34036.65, 0.00, 'Net wages for staff 3'),
(103, 52, 1000, 0.00, 34036.65, 'Net wages payment for staff 3'),
(104, 52, 37, 0.00, 4383.35, 'PAYE for staff 3'),
(105, 52, 39, 0.00, 1080.00, 'NSSF for staff 3'),
(106, 52, 40, 0.00, 500.00, 'NHIF for staff 3'),
(107, 53, 38, 37536.65, 0.00, 'Net wages for staff 2'),
(108, 53, 29, 0.00, 37536.65, 'Net wages payment for staff 2'),
(109, 53, 37, 0.00, 5883.35, 'PAYE for staff 2'),
(110, 53, 39, 0.00, 1080.00, 'NSSF for staff 2'),
(111, 53, 40, 0.00, 500.00, 'NHIF for staff 2'),
(112, 54, 38, 34036.65, 0.00, 'Net wages for staff 3'),
(113, 54, 23, 0.00, 34036.65, 'Net wages payment for staff 3'),
(114, 54, 37, 0.00, 4383.35, 'PAYE for staff 3'),
(115, 54, 39, 0.00, 1080.00, 'NSSF for staff 3'),
(116, 54, 40, 0.00, 500.00, 'NHIF for staff 3'),
(117, 55, 140, 148.50, 0.00, 'Invoice INV-2-1752397570019'),
(118, 55, 53, 0.00, 135.00, 'Sales revenue - INV-2-1752397570019'),
(119, 55, 35, 0.00, 13.50, 'Sales tax - INV-2-1752397570019'),
(120, 56, 63, 75.00, 0.00, 'COGS - INV-2-1752397570019'),
(121, 56, 10, 0.00, 75.00, 'Inventory reduction - INV-2-1752397570019'),
(122, 57, 21, 400.00, 0.00, 'Customer payment received'),
(123, 57, 140, 0.00, 400.00, 'Customer payment received'),
(124, 58, 23, 40.00, 0.00, 'Customer payment received'),
(125, 58, 140, 0.00, 40.00, 'Customer payment received'),
(126, 59, 23, 200.00, 0.00, 'Customer payment received'),
(127, 59, 140, 0.00, 200.00, 'Customer payment received'),
(128, 60, 23, 30.50, 0.00, 'Customer payment received'),
(129, 60, 140, 0.00, 30.50, 'Customer payment received'),
(130, 61, 30, 200.00, 0.00, 'Supplier payment'),
(131, 61, 24, 0.00, 200.00, 'Supplier payment'),
(132, 62, 10, 299.98, 0.00, 'Goods received for PO PO-000009'),
(133, 62, 30, 0.00, 299.98, 'Goods received for PO PO-000009'),
(134, 63, 10, 2000.00, 0.00, 'Goods received for PO PO-000010'),
(135, 63, 30, 0.00, 2000.00, 'Goods received for PO PO-000010'),
(136, 64, 140, 99.00, 0.00, 'Invoice INV-2-1752649457669'),
(137, 64, 53, 0.00, 85.34, 'Sales revenue - INV-2-1752649457669'),
(138, 64, 35, 0.00, 13.66, 'Sales tax - INV-2-1752649457669'),
(139, 65, 63, 55.00, 0.00, 'COGS - INV-2-1752649457669'),
(140, 65, 10, 0.00, 55.00, 'Inventory reduction - INV-2-1752649457669'),
(141, 66, 22, 99.00, 0.00, 'Customer payment received'),
(142, 66, 140, 0.00, 99.00, 'Customer payment received'),
(143, 67, 10, 3000.00, 0.00, 'Goods received for PO PO-000011'),
(144, 67, 30, 0.00, 3000.00, 'Goods received for PO PO-000011'),
(145, 68, 49, 0.00, 3000.00, 'test'),
(146, 69, 110, 5000.00, 0.00, 'test'),
(147, 69, 32, 0.00, 5000.00, 'test'),
(148, 70, 10, 200.00, 0.00, 'Goods received for PO PO-000012'),
(149, 70, 30, 0.00, 200.00, 'Goods received for PO PO-000012'),
(150, 71, 85, 2000.00, 0.00, 'desc'),
(151, 71, 23, 0.00, 2000.00, 'desc'),
(152, 72, 21, 200.00, 0.00, ''),
(153, 72, 24, 0.00, 200.00, ''),
(154, 73, 140, 2200.00, 0.00, 'Sales order SO-1753903474059'),
(155, 73, 53, 0.00, 2000.00, 'Sales revenue for order SO-1753903474059'),
(156, 73, 35, 0.00, 200.00, 'Sales tax for order SO-1753903474059'),
(157, 74, 140, 2200.00, 0.00, 'Sales order SO-1753903474059'),
(158, 74, 53, 0.00, 2000.00, 'Sales revenue for order SO-1753903474059'),
(159, 74, 35, 0.00, 200.00, 'Sales tax for order SO-1753903474059'),
(160, 75, 140, 2200.00, 0.00, 'Sales order SO-1753903474059'),
(161, 75, 53, 0.00, 2000.00, 'Sales revenue for order SO-1753903474059'),
(162, 75, 35, 0.00, 200.00, 'Sales tax for order SO-1753903474059'),
(163, 76, 140, 2200.00, 0.00, 'Sales order SO-1753900819864'),
(164, 76, 53, 0.00, 2000.00, 'Sales revenue for order SO-1753900819864'),
(165, 76, 35, 0.00, 200.00, 'Sales tax for order SO-1753900819864'),
(166, 77, 140, 2200.00, 0.00, 'Sales order SO-1753903474059'),
(167, 77, 53, 0.00, 2000.00, 'Sales revenue for order SO-1753903474059'),
(168, 77, 35, 0.00, 200.00, 'Sales tax for order SO-1753903474059'),
(169, 78, 140, 2200.00, 0.00, 'Invoice INV-34'),
(170, 78, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-34'),
(171, 78, 35, 0.00, 200.00, 'Sales tax for invoice INV-34'),
(172, 79, 140, 2200.00, 0.00, 'Sales order SO-2025-0002'),
(173, 79, 53, 0.00, 2000.00, 'Sales revenue for order SO-2025-0002'),
(174, 79, 35, 0.00, 200.00, 'Sales tax for order SO-2025-0002'),
(175, 80, 140, 11000.00, 0.00, 'Sales order SO-2025-0001'),
(176, 80, 53, 0.00, 10000.00, 'Sales revenue for order SO-2025-0001'),
(177, 80, 35, 0.00, 1000.00, 'Sales tax for order SO-2025-0001'),
(178, 81, 140, 2200.00, 0.00, 'Invoice INV-48'),
(179, 81, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-48'),
(180, 81, 35, 0.00, 200.00, 'Sales tax for invoice INV-48'),
(181, 82, 140, 11000.00, 0.00, 'Invoice INV-55'),
(182, 82, 53, 0.00, 10000.00, 'Sales revenue for invoice INV-55'),
(183, 82, 35, 0.00, 1000.00, 'Sales tax for invoice INV-55'),
(184, 83, 140, 6600.00, 0.00, 'Invoice INV-56'),
(185, 83, 53, 0.00, 6000.00, 'Sales revenue for invoice INV-56'),
(186, 83, 35, 0.00, 600.00, 'Sales tax for invoice INV-56'),
(187, 84, 140, 2200.00, 0.00, 'Invoice INV-57'),
(188, 84, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-57'),
(189, 84, 35, 0.00, 200.00, 'Sales tax for invoice INV-57'),
(190, 85, 140, 4400.00, 0.00, 'Invoice INV-58'),
(191, 85, 53, 0.00, 4000.00, 'Sales revenue for invoice INV-58'),
(192, 85, 35, 0.00, 400.00, 'Sales tax for invoice INV-58'),
(193, 86, 140, 6600.00, 0.00, 'Invoice INV-59'),
(194, 86, 53, 0.00, 6000.00, 'Sales revenue for invoice INV-59'),
(195, 86, 35, 0.00, 600.00, 'Sales tax for invoice INV-59'),
(196, 87, 23, 2000.00, 0.00, 'Customer payment received'),
(197, 87, 140, 0.00, 2000.00, 'Customer payment received'),
(198, 88, 23, 4.00, 0.00, 'Customer payment received'),
(199, 88, 140, 0.00, 4.00, 'Customer payment received'),
(200, 89, 53, 4000.00, 0.00, 'Credit Note CN-1754530076209 - test'),
(201, 89, 140, 0.00, 4000.00, 'Credit Note CN-1754530076209 - test'),
(202, 90, 53, 2000.00, 0.00, 'Credit Note CN-1754531048437 - n'),
(203, 90, 140, 0.00, 2000.00, 'Credit Note CN-1754531048437 - n'),
(204, 91, 140, 2200.00, 0.00, 'Invoice INV-60'),
(205, 91, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-60'),
(206, 91, 35, 0.00, 200.00, 'Sales tax for invoice INV-60'),
(207, 92, 140, 4400.00, 0.00, 'Invoice INV-61'),
(208, 92, 53, 0.00, 4000.00, 'Sales revenue for invoice INV-61'),
(209, 92, 35, 0.00, 400.00, 'Sales tax for invoice INV-61'),
(210, 93, 81, 1000.00, 0.00, 'test'),
(211, 93, 23, 0.00, 1000.00, 'test'),
(212, 94, 140, 2000.00, 0.00, 'Invoice INV-65'),
(213, 94, 53, 0.00, 1724.14, 'Sales revenue for invoice INV-65'),
(214, 94, 35, 0.00, 275.86, 'Sales tax for invoice INV-65'),
(215, 95, 10, 3900.00, 0.00, 'Goods received for PO PO-000014'),
(216, 95, 30, 0.00, 3900.00, 'Goods received for PO PO-000014'),
(217, 96, 10, 300.00, 0.00, 'Goods received for PO PO-000018'),
(218, 96, 30, 0.00, 300.00, 'Goods received for PO PO-000018'),
(219, 97, 30, 4.00, 0.00, 'Supplier payment'),
(220, 97, 24, 0.00, 4.00, 'Supplier payment'),
(221, 98, 30, 100.00, 0.00, 'Supplier payment'),
(222, 98, 24, 0.00, 100.00, 'Supplier payment'),
(223, 99, 140, 6000.00, 0.00, 'Invoice INV-70'),
(224, 99, 53, 0.00, 6000.00, 'Sales revenue for invoice INV-70'),
(225, 100, 38, -140.60, 0.00, 'Net wages for staff 1'),
(226, 100, 21, 0.00, -140.60, 'Net wages payment for staff 1'),
(227, 100, 39, 0.00, 0.60, 'NSSF for staff 1'),
(228, 100, 40, 0.00, 150.00, 'NHIF for staff 1'),
(229, 101, 38, 37536.65, 0.00, 'Net wages for staff 2'),
(230, 101, 21, 0.00, 37536.65, 'Net wages payment for staff 2'),
(231, 101, 37, 0.00, 5883.35, 'PAYE for staff 2'),
(232, 101, 39, 0.00, 1080.00, 'NSSF for staff 2'),
(233, 101, 40, 0.00, 500.00, 'NHIF for staff 2'),
(234, 102, 38, 34036.65, 0.00, 'Net wages for staff 3'),
(235, 102, 21, 0.00, 34036.65, 'Net wages payment for staff 3'),
(236, 102, 37, 0.00, 4383.35, 'PAYE for staff 3'),
(237, 102, 39, 0.00, 1080.00, 'NSSF for staff 3'),
(238, 102, 40, 0.00, 500.00, 'NHIF for staff 3'),
(239, 103, 38, 37536.65, 0.00, 'Net wages for staff 4'),
(240, 103, 21, 0.00, 37536.65, 'Net wages payment for staff 4'),
(241, 103, 37, 0.00, 5883.35, 'PAYE for staff 4'),
(242, 103, 39, 0.00, 1080.00, 'NSSF for staff 4'),
(243, 103, 40, 0.00, 500.00, 'NHIF for staff 4'),
(244, 104, 38, 26920.00, 0.00, 'Net wages for staff 5'),
(245, 104, 21, 0.00, 26920.00, 'Net wages payment for staff 5'),
(246, 104, 37, 0.00, 1500.00, 'PAYE for staff 5'),
(247, 104, 39, 0.00, 1080.00, 'NSSF for staff 5'),
(248, 104, 40, 0.00, 500.00, 'NHIF for staff 5'),
(249, 105, 38, 30536.65, 0.00, 'Net wages for staff 6'),
(250, 105, 21, 0.00, 30536.65, 'Net wages payment for staff 6'),
(251, 105, 37, 0.00, 2883.35, 'PAYE for staff 6'),
(252, 105, 39, 0.00, 1080.00, 'NSSF for staff 6'),
(253, 105, 40, 0.00, 500.00, 'NHIF for staff 6'),
(254, 106, 38, 34036.65, 0.00, 'Net wages for staff 7'),
(255, 106, 21, 0.00, 34036.65, 'Net wages payment for staff 7'),
(256, 106, 37, 0.00, 4383.35, 'PAYE for staff 7'),
(257, 106, 39, 0.00, 1080.00, 'NSSF for staff 7'),
(258, 106, 40, 0.00, 500.00, 'NHIF for staff 7'),
(259, 107, 38, -150.00, 0.00, 'Net wages for staff 8'),
(260, 107, 21, 0.00, -150.00, 'Net wages payment for staff 8'),
(261, 107, 40, 0.00, 150.00, 'NHIF for staff 8'),
(262, 108, 38, -150.00, 0.00, 'Net wages for staff 9'),
(263, 108, 21, 0.00, -150.00, 'Net wages payment for staff 9'),
(264, 108, 40, 0.00, 150.00, 'NHIF for staff 9'),
(265, 109, 140, 6000.00, 0.00, 'Invoice INV-64'),
(266, 109, 53, 0.00, 5172.41, 'Sales revenue for invoice INV-64'),
(267, 109, 35, 0.00, 827.59, 'Sales tax for invoice INV-64'),
(268, 110, 140, 0.00, 2000.00, 'Credit note CN-10171-1754860285275'),
(269, 110, 53, 1724.14, 0.00, 'Sales return - CN-10171-1754860285275'),
(270, 110, 35, 275.86, 0.00, 'Sales tax return - CN-10171-1754860285275'),
(271, 111, 140, 0.00, 4000.00, 'Credit note CN-10171-1754860759831'),
(272, 111, 53, 3448.28, 0.00, 'Sales return - CN-10171-1754860759831'),
(273, 111, 35, 551.72, 0.00, 'Sales tax return - CN-10171-1754860759831'),
(274, 112, 140, 0.00, 2000.00, 'Credit note CN-10171-1754860809623'),
(275, 112, 53, 1724.14, 0.00, 'Sales return - CN-10171-1754860809623'),
(276, 112, 35, 275.86, 0.00, 'Sales tax return - CN-10171-1754860809623'),
(277, 113, 140, 0.00, 2000.00, 'Credit note CN-10171-1754860834263'),
(278, 113, 53, 1724.14, 0.00, 'Sales return - CN-10171-1754860834263'),
(279, 113, 35, 275.86, 0.00, 'Sales tax return - CN-10171-1754860834263'),
(280, 114, 140, 0.00, 6000.00, 'Credit note CN-2221-1754861688533'),
(281, 114, 53, 5172.41, 0.00, 'Sales return - CN-2221-1754861688533'),
(282, 114, 35, 827.59, 0.00, 'Sales tax return - CN-2221-1754861688533'),
(283, 115, 140, 2000.00, 0.00, 'Invoice INV-71'),
(284, 115, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-71'),
(285, 116, 140, 2000.00, 0.00, 'Invoice INV-72'),
(286, 116, 53, 0.00, 1724.14, 'Sales revenue for invoice INV-72'),
(287, 116, 35, 0.00, 275.86, 'Sales tax for invoice INV-72'),
(288, 117, 140, 2000.00, 0.00, 'Invoice INV-73'),
(289, 117, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-73'),
(290, 118, 23, 2000.00, 0.00, 'Customer payment received'),
(291, 118, 140, 0.00, 2000.00, 'Customer payment received'),
(292, 119, 140, 0.00, 2000.00, 'Credit note CN-2221-1755578549613'),
(293, 119, 53, 1724.14, 0.00, 'Sales return - CN-2221-1755578549613'),
(294, 119, 35, 275.86, 0.00, 'Sales tax return - CN-2221-1755578549613'),
(295, 120, 140, 387.93, 0.00, 'Invoice INV-74'),
(296, 120, 53, 0.00, 334.42, 'Sales revenue for invoice INV-74'),
(297, 120, 35, 0.00, 53.51, 'Sales tax for invoice INV-74'),
(298, 121, 10, 200.00, 0.00, 'Goods received for PO PO-000019'),
(299, 121, 30, 0.00, 200.00, 'Goods received for PO PO-000019'),
(300, 122, 140, 450.00, 0.00, 'Invoice INV-75'),
(301, 122, 53, 0.00, 387.93, 'Sales revenue for invoice INV-75'),
(302, 122, 35, 0.00, 62.07, 'Sales tax for invoice INV-75'),
(303, 123, 140, 3800.00, 0.00, 'Invoice INV-76'),
(304, 123, 53, 0.00, 3800.00, 'Sales revenue for invoice INV-76'),
(305, 124, 140, 387.93, 0.00, 'Invoice INV-77'),
(306, 124, 53, 0.00, 334.42, 'Sales revenue for invoice INV-77'),
(307, 124, 35, 0.00, 53.51, 'Sales tax for invoice INV-77'),
(308, 125, 140, 450.00, 0.00, 'Invoice INV-78'),
(309, 125, 53, 0.00, 387.93, 'Sales revenue for invoice INV-78'),
(310, 125, 35, 0.00, 62.07, 'Sales tax for invoice INV-78'),
(311, 126, 140, 200.00, 0.00, 'Invoice INV-87'),
(312, 126, 53, 0.00, 172.41, 'Sales revenue for invoice INV-87'),
(313, 126, 35, 0.00, 27.59, 'Sales tax for invoice INV-87'),
(314, 127, 140, 232.00, 0.00, 'Invoice INV-88'),
(315, 127, 53, 0.00, 200.00, 'Sales revenue for invoice INV-88'),
(316, 127, 35, 0.00, 32.00, 'Sales tax for invoice INV-88'),
(317, 128, 140, 2320.00, 0.00, 'Invoice INV-95'),
(318, 128, 53, 0.00, 2000.00, 'Sales revenue for invoice INV-95'),
(319, 128, 35, 0.00, 320.00, 'Sales tax for invoice INV-95'),
(320, 129, 140, 9600.00, 0.00, 'Invoice INV-96'),
(321, 129, 53, 0.00, 9600.00, 'Sales revenue for invoice INV-96'),
(322, 130, 140, 10800.00, 0.00, 'Invoice INV-97'),
(323, 130, 53, 0.00, 10800.00, 'Sales revenue for invoice INV-97'),
(324, 131, 140, 1100.00, 0.00, 'Invoice INV-98'),
(325, 131, 53, 0.00, 1100.00, 'Sales revenue for invoice INV-98');

-- --------------------------------------------------------

--
-- Table structure for table `JourneyPlan`
--

CREATE TABLE `JourneyPlan` (
  `id` int(11) NOT NULL,
  `date` datetime(3) NOT NULL,
  `time` varchar(191) NOT NULL,
  `userId` int(11) DEFAULT NULL,
  `clientId` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 0,
  `checkInTime` datetime(3) DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `imageUrl` varchar(191) DEFAULT NULL,
  `notes` varchar(191) DEFAULT NULL,
  `checkoutLatitude` double DEFAULT NULL,
  `checkoutLongitude` double DEFAULT NULL,
  `checkoutTime` datetime(3) DEFAULT NULL,
  `showUpdateLocation` tinyint(1) NOT NULL DEFAULT 1,
  `routeId` int(11) DEFAULT NULL,
  `createdAt` varchar(50) NOT NULL,
  `updatedAt` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `JourneyPlan`
--

INSERT INTO `JourneyPlan` (`id`, `date`, `time`, `userId`, `clientId`, `status`, `checkInTime`, `latitude`, `longitude`, `imageUrl`, `notes`, `checkoutLatitude`, `checkoutLongitude`, `checkoutTime`, `showUpdateLocation`, `routeId`, `createdAt`, `updatedAt`) VALUES
(8030, '2025-08-27 00:00:00.000', '21:21', 94, 10653, 3, '2025-08-27 21:22:02.512', -1.2149507594042805, 36.88711490929877, 'https://res.cloudinary.com/otienobryan/image/upload/v1756318921/whoosh/uploads/upload_1756318921689_undefined.jpg', NULL, -1.2149507594042805, 36.88711490929877, '2025-08-27 21:36:02.898', 1, NULL, '', ''),
(8031, '2025-08-27 00:00:00.000', '21:37', 94, 10653, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8032, '2025-08-28 00:00:00.000', '12:27', 94, 10747, 1, '2025-08-28 12:27:55.301', -1.3009241, 36.7777894, 'https://res.cloudinary.com/otienobryan/image/upload/v1756373273/whoosh/uploads/upload_1756373273447_undefined.jpg', 'tes', NULL, NULL, NULL, 1, NULL, '', ''),
(8033, '2025-09-02 00:00:00.000', '17:32', 129, 10653, 3, '2025-09-02 17:33:08.769', -1.3009987, 36.7776122, 'https://res.cloudinary.com/otienobryan/image/upload/v1756823587/whoosh/uploads/upload_1756823587695_undefined.jpg', NULL, -1.3009279, 36.7776932, '2025-09-02 17:34:46.249', 1, NULL, '', ''),
(8034, '2025-09-02 00:00:00.000', '22:33', 129, 10747, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8035, '2025-09-02 00:00:00.000', '22:54', 94, 10779, 1, '2025-09-02 22:55:52.875', -1.2921, 36.8219, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8036, '2025-09-03 00:00:00.000', '06:55', 162, 10713, 3, '2025-09-03 06:57:00.412', -1.2494903, 36.8618641, 'https://res.cloudinary.com/otienobryan/image/upload/v1756871818/whoosh/uploads/upload_1756871818485_undefined.jpg', NULL, -1.2501513, 36.8614425, '2025-09-03 10:14:36.750', 1, NULL, '', ''),
(8038, '2025-09-03 00:00:00.000', '07:02', 185, 10747, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8039, '2025-09-03 00:00:00.000', '07:12', 153, 10631, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8040, '2025-09-03 00:00:00.000', '07:27', 191, 10690, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8041, '2025-09-03 00:00:00.000', '07:29', 156, 10645, 3, '2025-09-03 07:33:26.304', -1.2711436, 36.9967355, 'https://res.cloudinary.com/otienobryan/image/upload/v1756874005/whoosh/uploads/upload_1756874005569_undefined.jpg', NULL, -1.2707173, 36.9967795, '2025-09-03 09:50:01.339', 1, NULL, '', ''),
(8042, '2025-09-03 00:00:00.000', '07:33', 155, 10641, 1, '2025-09-03 07:37:19.511', -1.2783426, 36.8835362, 'https://res.cloudinary.com/otienobryan/image/upload/v1756874239/whoosh/uploads/upload_1756874238904_undefined.jpg', NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8045, '2025-09-03 00:00:00.000', '07:30', 138, 10730, 3, '2025-09-03 08:38:02.263', -1.2709919, 36.8129979, 'https://res.cloudinary.com/otienobryan/image/upload/v1756877883/whoosh/uploads/upload_1756877883303_undefined.jpg', NULL, -1.2712296, 36.8126931, '2025-09-03 09:26:31.012', 1, NULL, '', ''),
(8046, '2025-09-03 00:00:00.000', '08:12', 235, 10769, 3, '2025-09-03 08:22:17.624', -1.289871, 36.7733097, 'https://res.cloudinary.com/otienobryan/image/upload/v1756876938/whoosh/uploads/upload_1756876938316_undefined.jpg', NULL, -1.2895516, 36.7729751, '2025-09-03 09:46:50.082', 1, NULL, '', ''),
(8047, '2025-09-03 00:00:00.000', '08:13', 160, 10648, 3, '2025-09-03 08:14:42.217', -1.2669963, 37.3182835, 'https://res.cloudinary.com/otienobryan/image/upload/v1756876483/whoosh/uploads/upload_1756876483201_undefined.jpg', NULL, -1.2672364, 37.3184682, '2025-09-03 09:16:50.671', 1, NULL, '', ''),
(8048, '2025-09-03 00:00:00.000', '08:17', 161, 10647, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8051, '2025-09-03 00:00:00.000', '08:27', 178, 10728, 3, '2025-09-03 08:37:06.156', -1.2594954, 36.8179519, 'https://res.cloudinary.com/otienobryan/image/upload/v1756877825/whoosh/uploads/upload_1756877825263_undefined.jpg', NULL, -1.2597799, 36.8176607, '2025-09-03 08:45:21.825', 1, NULL, '', ''),
(8052, '2025-09-03 00:00:00.000', '10:30', 138, 10729, 3, '2025-09-03 11:03:55.311', -1.2639807, 36.8029606, 'https://res.cloudinary.com/otienobryan/image/upload/v1756886636/whoosh/uploads/upload_1756886636668_undefined.jpg', NULL, -1.2649534, 36.8027104, '2025-09-03 13:37:35.992', 1, NULL, '', ''),
(8053, '2025-09-03 00:00:00.000', '12:30', 138, 10732, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8054, '2025-09-03 00:00:00.000', '08:45', 178, 10728, 3, '2025-09-03 08:47:53.600', -1.2597999, 36.8176696, 'https://res.cloudinary.com/otienobryan/image/upload/v1756878472/whoosh/uploads/upload_1756878472837_undefined.jpg', NULL, -1.2611442, 36.8197733, '2025-09-03 11:09:23.760', 1, NULL, '', ''),
(8056, '2025-09-03 00:00:00.000', '08:52', 94, 10604, 3, '2025-09-03 08:53:02.898', -1.3009314, 36.7777261, NULL, NULL, -1.3009262, 36.7777295, '2025-09-03 08:58:03.155', 1, NULL, '', ''),
(8057, '2025-09-03 00:00:00.000', '08:59', 94, 10604, 3, '2025-09-03 09:00:10.250', -1.3009298, 36.7777192, NULL, NULL, -1.300925, 36.7777323, '2025-09-03 09:04:04.643', 1, NULL, '', ''),
(8058, '2025-09-03 00:00:00.000', '09:08', 94, 10608, 3, '2025-09-03 09:08:45.961', -1.300942, 36.7777139, NULL, NULL, -1.300939, 36.7777184, '2025-09-03 09:10:00.093', 1, NULL, '', ''),
(8059, '2025-09-03 00:00:00.000', '09:50', 137, 10772, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8060, '2025-09-03 00:00:00.000', '10:08', 235, 10770, 3, '2025-09-03 10:09:24.345', -1.2801018, 36.7706929, 'https://res.cloudinary.com/otienobryan/image/upload/v1756883365/whoosh/uploads/upload_1756883365028_undefined.jpg', NULL, -1.2785567, 36.7698343, '2025-09-03 11:43:55.193', 1, NULL, '', ''),
(8061, '2025-09-03 00:00:00.000', '10:11', 153, 10630, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8062, '2025-09-03 00:00:00.000', '10:30', 191, 10691, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8063, '2025-09-03 00:00:00.000', '10:31', 137, 10771, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8064, '2025-09-03 00:00:00.000', '10:36', 185, 10748, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8065, '2025-09-03 00:00:00.000', '10:39', 202, 10748, 1, '2025-09-03 10:42:12.030', 0.2892346, 34.7576087, 'https://res.cloudinary.com/otienobryan/image/upload/v1756885334/whoosh/uploads/upload_1756885333986_undefined.jpg', 'not', NULL, NULL, NULL, 1, NULL, '', ''),
(8066, '2025-09-03 00:00:00.000', '10:46', 162, 10718, 3, '2025-09-03 10:48:11.905', -1.2410652, 36.8904399, 'https://res.cloudinary.com/otienobryan/image/upload/v1756885691/whoosh/uploads/upload_1756885690906_undefined.jpg', NULL, -1.2411162, 36.8902706, '2025-09-03 13:27:01.920', 1, NULL, '', ''),
(8067, '2025-09-03 00:00:00.000', '11:13', 178, 10727, 3, '2025-09-03 11:21:16.130', -1.2625146, 36.8233923, 'https://res.cloudinary.com/otienobryan/image/upload/v1756887675/whoosh/uploads/upload_1756887675303_undefined.jpg', NULL, -1.2847047, 36.9008307, '2025-09-03 14:01:53.468', 1, NULL, '', ''),
(8068, '2025-09-03 00:00:00.000', '11:32', 191, 10689, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8069, '2025-09-03 00:00:00.000', '06:20', 222, 10632, 0, NULL, NULL, NULL, NULL, 'add of facing', NULL, NULL, NULL, 1, NULL, '', ''),
(8070, '2025-09-03 00:00:00.000', '09:00', 222, 10621, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8071, '2025-09-03 00:00:00.000', '12:25', 222, 10643, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8072, '2025-09-03 00:00:00.000', '13:37', 191, 10694, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8073, '2025-09-03 00:00:00.000', '13:51', 94, 10780, 1, '2025-09-03 13:53:01.890', -1.3009752, 36.777756, 'https://res.cloudinary.com/otienobryan/image/upload/v1756896779/whoosh/uploads/upload_1756896779773_undefined.jpg', NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8075, '2025-09-03 00:00:00.000', '14:42', 161, 10659, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8076, '2025-09-04 00:00:00.000', '07:05', 174, 10797, 1, '2025-09-04 07:07:12.913', -1.2225821, 36.7810818, 'https://res.cloudinary.com/otienobryan/image/upload/v1756958832/whoosh/uploads/upload_1756958831825_undefined.jpg', NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8077, '2025-09-04 00:00:00.000', '07:05', 174, 10798, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8078, '2025-09-04 00:00:00.000', '07:08', 185, 10747, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8079, '2025-09-04 00:00:00.000', '07:04', 222, 10632, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8081, '2025-09-04 00:00:00.000', '07:40', 94, 10604, 1, '2025-09-04 07:49:12.302', -1.3008953103134218, 36.77774413639535, 'https://res.cloudinary.com/otienobryan/image/upload/v1756961351/whoosh/uploads/upload_1756961351330_undefined.jpg', NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8082, '2025-09-04 00:00:00.000', '07:40', 161, 10663, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8083, '2025-09-04 00:00:00.000', '07:40', 154, 10635, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8084, '2025-09-04 00:00:00.000', '07:43', 191, 10690, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8085, '2025-09-04 00:00:00.000', '07:46', 178, 10728, 1, '2025-09-04 07:48:45.044', -1.2848516, 36.8998553, 'https://res.cloudinary.com/otienobryan/image/upload/v1756961324/whoosh/uploads/upload_1756961324223_undefined.jpg', NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8087, '2025-09-04 00:00:00.000', '07:47', 234, 10776, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8088, '2025-09-04 00:00:00.000', '07:30', 138, 10732, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8089, '2025-09-04 00:00:00.000', '07:49', 137, 10773, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8090, '2025-09-04 00:00:00.000', '11:00', 138, 10729, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', ''),
(8091, '2025-09-04 00:00:00.000', '07:55', 165, 10700, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, '', '');

-- --------------------------------------------------------

--
-- Table structure for table `key_account_targets`
--

CREATE TABLE `key_account_targets` (
  `id` int(11) NOT NULL,
  `sales_rep_id` int(11) NOT NULL,
  `vapes_targets` int(11) DEFAULT 0,
  `pouches_targets` int(11) DEFAULT 0,
  `new_outlets_targets` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `target_month` varchar(7) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `key_account_targets`
--

INSERT INTO `key_account_targets` (`id`, `sales_rep_id`, `vapes_targets`, `pouches_targets`, `new_outlets_targets`, `created_at`, `target_month`, `start_date`, `end_date`) VALUES
(3, 4, 40, 10, 0, '2025-07-18 07:57:59', '2025-07', '2025-07-01', '2025-07-31'),
(4, 4, 4, 0, 0, '2025-07-18 08:00:23', '2025-06', '2025-07-01', '2025-07-31'),
(5, 94, 100, 40, 2, '2025-07-22 18:37:39', '2025-07', '2025-07-01', '2025-07-31');

-- --------------------------------------------------------

--
-- Table structure for table `LeaveRequestSummary`
--

CREATE TABLE `LeaveRequestSummary` (
  `id` int(11) DEFAULT NULL,
  `employee_id` int(11) DEFAULT NULL,
  `leave_type_id` int(11) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `is_half_day` tinyint(1) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `attachment_url` varchar(255) DEFAULT NULL,
  `status` enum('pending','approved','rejected','cancelled') DEFAULT NULL,
  `approved_by` int(11) DEFAULT NULL,
  `employee_type_id` int(11) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `applied_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `employee_name` varchar(255) DEFAULT NULL,
  `employee_email` varchar(255) DEFAULT NULL,
  `employee_phone` varchar(50) DEFAULT NULL,
  `leave_type_name` varchar(100) DEFAULT NULL,
  `leave_type_default_days` int(11) DEFAULT NULL,
  `approver_name` varchar(255) DEFAULT NULL,
  `total_days_requested` int(9) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `leaves`
--

CREATE TABLE `leaves` (
  `id` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `leaveType` varchar(191) NOT NULL,
  `startDate` datetime(3) NOT NULL,
  `endDate` datetime(3) NOT NULL,
  `reason` varchar(191) NOT NULL,
  `attachment` varchar(191) DEFAULT NULL,
  `status` varchar(191) NOT NULL DEFAULT 'PENDING',
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `updatedAt` datetime(3) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leaves`
--

INSERT INTO `leaves` (`id`, `userId`, `leaveType`, `startDate`, `endDate`, `reason`, `attachment`, `status`, `createdAt`, `updatedAt`) VALUES
(5, 9, 'Annual', '2025-05-21 00:00:00.000', '2025-05-24 00:00:00.000', 'Annual Leave ', NULL, '1', '2025-05-20 07:11:38.806', '2025-05-20 07:11:38.806'),
(6, 36, 'Annual', '2025-05-26 00:00:00.000', '2025-05-26 00:00:00.000', 'Going to apply for my Nation Identity card, to resume back on duty from 2pm', NULL, '1', '2025-05-25 12:01:29.176', '2025-05-25 12:01:29.176'),
(11, 39, 'Annual', '2025-05-28 00:00:00.000', '2025-05-31 00:00:00.000', 'official graduation happening at kasarani technical and vocational college,I will be one of the graduants', NULL, '1', '2025-05-27 10:41:13.596', '2025-05-27 10:41:13.596'),
(12, 36, 'Annual', '2025-05-31 00:00:00.000', '2025-05-31 00:00:00.000', 'Attending my son\'s school meeting ', NULL, '1', '2025-05-28 11:58:53.703', '2025-05-28 11:58:53.703'),
(13, 46, 'Sick', '2025-05-30 00:00:00.000', '2025-06-01 00:00:00.000', 'Started feeling unwell early this week, it developed to a boil, severe headaches, tonsils. \nwas finding it hard engaging clients as of today, 29th May.\nrequesting for a 2 day sick leave for m', 'https://ik.imagekit.io/bja2qwwdjjy/whoosh/leave-documents/1748522867858-202666836_z5PYrjhVm.jpg', '1', '2025-05-29 12:47:49.805', '2025-05-29 12:47:49.805'),
(17, 19, 'Annual', '2025-06-11 00:00:00.000', '2025-06-14 00:00:00.000', 'I am needed to travel for a few days to follow up on a personal matter ', NULL, '1', '2025-06-10 06:21:58.564', '2025-06-10 06:21:58.564'),
(18, 51, 'Sick', '2025-06-17 00:00:00.000', '2025-06-19 00:00:00.000', 'I am currently sick and as per the doctors advise i need a few days off.', 'https://ik.imagekit.io/bja2qwwdjjy/whoosh/leave-documents/1750099374520-599822857_jXHokN0tC.jpg', '1', '2025-06-16 18:42:57.248', '2025-06-16 18:42:57.248'),
(19, 32, 'Paternal', '2025-06-18 00:00:00.000', '2025-06-21 00:00:00.000', 'Taking my wife to Deliver', 'https://ik.imagekit.io/bja2qwwdjjy/whoosh/leave-documents/1750139033275-492141867_fssZe8Vm_.jpg', '1', '2025-06-17 05:43:56.281', '2025-06-17 05:43:56.281'),
(22, 66, 'Paternal', '2025-06-18 00:00:00.000', '2025-09-01 00:00:00.000', 'maternity ', 'https://ik.imagekit.io/bja2qwwdjjy/whoosh/leave-documents/1750151604407-225208299_yizeXT5ze.pdf', '1', '2025-06-17 09:13:26.647', '2025-06-17 09:13:26.647'),
(24, 23, 'Sick', '2025-06-19 00:00:00.000', '2025-06-19 00:00:00.000', 'I woke up feeling sick and had to seek medical attention. Attached is my medical note.', 'https://ik.imagekit.io/bja2qwwdjjy/whoosh/leave-documents/1750239968304-103586841_YG6tYYmpi.jpg', '1', '2025-06-18 09:46:12.244', '2025-06-18 09:46:12.244'),
(28, 6, 'Sick', '2025-06-21 00:00:00.000', '2025-06-23 00:00:00.000', 'not feeling well.', 'https://res.cloudinary.com/otienobryan/image/upload/v1750417546/whoosh/leave-documents/1750417545050-document.pdf', '1', '2025-06-20 11:05:46.620', '2025-06-20 11:05:46.620'),
(32, 7, 'Annual', '2025-06-24 00:00:00.000', '2025-06-24 00:00:00.000', 'To attend school meeting kindly ', NULL, '1', '2025-06-21 18:10:09.846', '2025-06-21 18:10:09.846'),
(33, 21, 'Sick Leave', '2025-06-24 19:41:40.000', '2025-06-26 19:41:40.000', 'was sick', 'https://ik.imagekit.io/bja2qwwdjjy/leave-documents/WhatsApp%20Image%202025-06-26%20at%2019.42.32_3f749777_RdNBdYHVA.jpg?updatedAt=1750956254731', '1', '2025-06-26 19:41:40.000', '2025-06-21 18:10:09.846'),
(34, 46, 'Sick', '2025-07-01 00:00:00.000', '2025-07-06 00:00:00.000', 'sick, assaulted.', 'https://ik.imagekit.io/bja2qwwdjjy/leave-documents/leave-1751365878283_H1gjE4a9i.jpg', '1', '2025-07-01 10:31:19.276', '2025-08-19 13:43:01.737'),
(35, 7, 'Annual', '2025-07-09 00:00:00.000', '2025-07-14 00:00:00.000', 'annual leave ', NULL, '3', '2025-07-02 12:43:29.960', '2025-08-20 05:01:27.861'),
(36, 17, 'Annual', '2025-07-04 00:00:00.000', '2025-07-11 00:00:00.000', 'kindly requesting for a annual leave to visit family gathering for my sister\'s fundraising harambee to join university ', NULL, '3', '2025-07-04 06:22:11.067', '2025-08-20 05:01:33.786'),
(37, 48, 'Annual', '2025-07-11 00:00:00.000', '2025-07-11 00:00:00.000', 'going to court for an accident case', NULL, '1', '2025-07-11 08:49:30.703', '2025-08-19 12:04:21.037'),
(38, 91, 'Annual', '2025-07-19 00:00:00.000', '2025-07-19 00:00:00.000', 'family emergency ', NULL, '3', '2025-07-18 13:14:55.767', '2025-08-18 16:42:01.367'),
(39, 94, 'Annual', '2025-08-05 00:00:00.000', '2025-08-07 00:00:00.000', 'Vacation', NULL, 'PENDING', '2025-08-02 17:12:52.514', '0000-00-00 00:00:00.000'),
(40, 0, 'Annual', '2025-08-02 00:00:00.000', '2025-08-29 00:00:00.000', 'test test test \n', NULL, 'PENDING', '2025-08-02 17:16:36.011', '0000-00-00 00:00:00.000'),
(41, 94, 'Annual', '2025-08-05 00:00:00.000', '2025-08-07 00:00:00.000', 'Vacation test', NULL, 'PENDING', '2025-08-02 17:22:45.430', '0000-00-00 00:00:00.000'),
(42, 94, 'Annual', '2025-08-03 00:00:00.000', '2025-08-09 00:00:00.000', 'this is a test\n', NULL, 'PENDING', '2025-08-02 17:24:19.313', '0000-00-00 00:00:00.000'),
(43, 94, '', '0000-00-00 00:00:00.000', '0000-00-00 00:00:00.000', '', NULL, 'PENDING', '2025-08-02 17:47:34.760', '0000-00-00 00:00:00.000'),
(44, 94, 'Annual Leave', '2025-08-02 00:00:00.000', '2025-08-09 00:00:00.000', 'tesy test ', NULL, 'PENDING', '2025-08-02 21:30:43.181', '0000-00-00 00:00:00.000'),
(45, 94, 'Annual Leave', '2025-08-02 00:00:00.000', '2025-08-09 00:00:00.000', 'hhhhjjikkkkkkkkkkkk', NULL, 'PENDING', '2025-08-02 21:31:31.067', '0000-00-00 00:00:00.000'),
(46, 94, 'Annual', '2025-08-01 03:00:00.000', '2025-08-09 03:00:00.000', 'poiuuytrewwq', NULL, 'PENDING', '2025-08-02 21:34:33.720', '0000-00-00 00:00:00.000'),
(47, 94, 'Annual Leave', '2025-08-02 03:00:00.000', '2025-08-05 03:00:00.000', 'fggggffffftest\n', NULL, 'PENDING', '2025-08-02 21:58:30.437', '0000-00-00 00:00:00.000'),
(48, 94, 'Annual Leave', '2025-08-02 03:00:00.000', '2025-08-15 03:00:00.000', 'ouyiiuyyfftyuuuuuuhhggffd', NULL, 'PENDING', '2025-08-02 22:15:24.353', '0000-00-00 00:00:00.000'),
(49, 94, 'Annual Leave', '2025-08-13 03:00:00.000', '2025-08-16 03:00:00.000', 'bhhhgggzxcxzzzzzz', NULL, 'PENDING', '2025-08-02 22:18:43.192', '0000-00-00 00:00:00.000'),
(50, 94, 'Annual Leave', '2025-08-07 03:00:00.000', '2025-08-28 03:00:00.000', 'I tried to call you at 02-08-25 22:36. UNLIMITED calls like never before!! Hurry up and dial *444# to get this awesome offer while it lasts! ', NULL, 'PENDING', '2025-08-02 22:20:05.894', '0000-00-00 00:00:00.000'),
(51, 94, 'Annual Leave', '2025-08-03 00:00:00.000', '2025-08-27 00:00:00.000', 'tr you ytr ytr', NULL, 'PENDING', '2025-08-03 01:57:13.805', '0000-00-00 00:00:00.000'),
(52, 34, 'Maternity Leave', '2025-08-15 00:00:00.000', '2025-11-05 00:00:00.000', 'maternity leave request. ', NULL, '1', '2025-08-07 10:59:26.587', '2025-08-19 12:04:16.903'),
(53, 16, 'Sick Leave', '2025-08-18 00:00:00.000', '2025-08-20 00:00:00.000', 'Sick. Having a running stomach since yesterday ', NULL, 'PENDING', '2025-08-18 10:35:00.860', '0000-00-00 00:00:00.000'),
(54, 16, 'Sick Leave', '2025-08-18 00:00:00.000', '2025-08-19 00:00:00.000', 'Not feeling well ', NULL, '1', '2025-08-18 13:37:46.369', '2025-08-19 12:04:15.290'),
(55, 94, 'Sick Leave', '2025-08-18 00:00:00.000', '2025-08-23 00:00:00.000', 'this is abtest', NULL, 'PENDIN0', '2025-08-18 13:47:31.443', '0000-00-00 00:00:00.000'),
(56, 16, 'Sick', '2025-08-18 16:41:03.000', '2025-08-19 16:41:03.000', 'Not feeling well ', '', '1', '2025-08-18 16:41:03.000', '2025-08-19 12:04:12.483'),
(57, 94, 'Sick Leave', '2025-08-18 00:00:00.000', '2025-08-30 00:00:00.000', 'comfirm if it sleav', NULL, '1', '2025-08-18 15:48:41.546', '2025-08-19 13:42:54.906'),
(58, 94, 'Sick Leave', '2025-08-19 03:00:00.000', '2025-08-30 03:00:00.000', ' [DatabaseHealthService] Database connection is healthy\n', NULL, 'PENDING', '2025-08-18 22:25:37.537', '0000-00-00 00:00:00.000'),
(59, 94, 'Sick Leave', '2025-08-20 03:00:00.000', '2025-08-30 03:00:00.000', 'this is a last test', '/uploads/undefined', 'PENDING', '2025-08-18 22:28:55.849', '0000-00-00 00:00:00.000'),
(60, 94, 'Sick Leave', '2025-08-18 03:00:00.000', '2025-08-31 03:00:00.000', '/uploads/undefined', 'https://res.cloudinary.com/otienobryan/image/upload/v1755549119/whoosh/leave-attachments/lyr6ygdirthnrgcbotyz.jpg', 'PENDING', '2025-08-18 22:32:00.477', '0000-00-00 00:00:00.000'),
(61, 23, 'Sick Leave', '2025-08-21 00:00:00.000', '2025-08-22 00:00:00.000', 'I had food poisoning yesterday and woke up feeling sick', NULL, 'PENDING', '2025-08-22 11:37:16.526', '0000-00-00 00:00:00.000'),
(62, 20, 'Sick Leave', '2025-08-22 00:00:00.000', '2025-08-23 00:00:00.000', 'I am unwell', NULL, 'PENDING', '2025-08-22 16:58:26.835', '0000-00-00 00:00:00.000'),
(63, 6, 'Sick Leave', '2025-08-26 00:00:00.000', '2025-08-28 00:00:00.000', 'my son not feeling well.', NULL, 'PENDING', '2025-08-26 08:52:44.457', '0000-00-00 00:00:00.000'),
(64, 10, 'Sick Leave', '2025-08-26 00:00:00.000', '2025-08-27 00:00:00.000', 'I kindly need to take my kids back to School today,I\'m the available parent.', NULL, 'PENDING', '2025-08-26 11:22:46.622', '0000-00-00 00:00:00.000');

-- --------------------------------------------------------

--
-- Table structure for table `leave_balances`
--

CREATE TABLE `leave_balances` (
  `id` int(11) NOT NULL,
  `employee_id` int(11) NOT NULL,
  `leave_type_id` int(11) NOT NULL,
  `year` int(4) NOT NULL,
  `total_days` int(11) NOT NULL DEFAULT 0,
  `used_days` int(11) NOT NULL DEFAULT 0,
  `remaining_days` int(11) NOT NULL DEFAULT 0,
  `carried_over_days` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leave_balances`
--

INSERT INTO `leave_balances` (`id`, `employee_id`, `leave_type_id`, `year`, `total_days`, `used_days`, `remaining_days`, `carried_over_days`, `created_at`, `updated_at`) VALUES
(1, 8, 1, 2025, 21, 0, 21, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(2, 8, 2, 2025, 14, 0, 14, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(3, 8, 3, 2025, 90, 0, 90, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(4, 8, 4, 2025, 14, 0, 14, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(5, 8, 5, 2025, 5, 0, 5, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(6, 8, 6, 2025, 10, 0, 10, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(7, 8, 7, 2025, 0, 0, 0, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34'),
(8, 8, 8, 2025, 0, 0, 0, 0, '2025-07-18 15:54:34', '2025-07-18 15:54:34');

-- --------------------------------------------------------

--
-- Table structure for table `leave_requests`
--

CREATE TABLE `leave_requests` (
  `id` int(11) NOT NULL,
  `employee_id` int(11) DEFAULT NULL,
  `leave_type_id` int(11) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `is_half_day` tinyint(1) NOT NULL DEFAULT 0,
  `reason` varchar(255) DEFAULT NULL,
  `attachment_url` varchar(255) DEFAULT NULL,
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `approved_by` int(11) DEFAULT NULL,
  `employee_type_id` int(11) DEFAULT NULL,
  `salesrep` int(11) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leave_requests`
--

INSERT INTO `leave_requests` (`id`, `employee_id`, `leave_type_id`, `start_date`, `end_date`, `is_half_day`, `reason`, `attachment_url`, `status`, `approved_by`, `employee_type_id`, `salesrep`, `notes`, `applied_at`, `created_at`, `updated_at`) VALUES
(5, NULL, 1, '2025-08-07', '2025-08-28', 0, 'I tried to call you at 02-08-25 22:36. UNLIMITED calls like never before!! Hurry up and dial *444# to get this awesome offer while it lasts! ', NULL, 'pending', NULL, NULL, 94, NULL, '2025-08-02 22:20:07', '2025-08-02 18:20:07', '2025-08-02 18:20:07'),
(6, NULL, 1, '2025-08-03', '2025-08-27', 0, 'tr you ytr ytr', NULL, 'pending', NULL, NULL, 94, NULL, '2025-08-03 01:57:15', '2025-08-02 21:57:15', '2025-08-02 21:57:15'),
(7, NULL, 3, '2025-08-15', '2025-11-05', 0, 'maternity leave request. ', NULL, 'pending', NULL, NULL, 34, NULL, '2025-08-07 10:59:27', '2025-08-07 08:59:27', '2025-08-07 08:59:27'),
(8, NULL, 2, '2025-08-18', '2025-08-20', 0, 'Sick. Having a running stomach since yesterday ', NULL, 'pending', NULL, NULL, 16, NULL, '2025-08-18 10:35:02', '2025-08-18 08:35:02', '2025-08-18 08:35:02'),
(9, NULL, 2, '2025-08-18', '2025-08-19', 0, 'Not feeling well ', NULL, 'pending', NULL, NULL, 16, NULL, '2025-08-18 13:37:47', '2025-08-18 11:37:47', '2025-08-18 11:37:47'),
(15, NULL, 2, '2025-08-21', '2025-08-22', 0, 'I had food poisoning yesterday and woke up feeling sick', NULL, 'pending', NULL, NULL, 23, NULL, '2025-08-22 11:37:17', '2025-08-22 09:37:17', '2025-08-22 09:37:17'),
(16, NULL, 2, '2025-08-22', '2025-08-23', 0, 'I am unwell', NULL, 'pending', NULL, NULL, 20, NULL, '2025-08-22 16:58:27', '2025-08-22 14:58:27', '2025-08-22 14:58:27'),
(17, NULL, 2, '2025-08-26', '2025-08-28', 0, 'my son not feeling well.', NULL, 'pending', NULL, NULL, 6, NULL, '2025-08-26 08:52:45', '2025-08-26 06:52:45', '2025-08-26 06:52:45'),
(18, NULL, 2, '2025-08-26', '2025-08-27', 0, 'I kindly need to take my kids back to School today,I\'m the available parent.', NULL, 'pending', NULL, NULL, 10, NULL, '2025-08-26 11:22:47', '2025-08-26 09:22:47', '2025-08-26 09:22:47');

-- --------------------------------------------------------

--
-- Table structure for table `leave_types`
--

CREATE TABLE `leave_types` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `default_days` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `leave_types`
--

INSERT INTO `leave_types` (`id`, `name`, `description`, `default_days`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'Annual Leave', 'Regular annual leave entitlement', 21, 1, '2025-07-18 15:39:49', '2025-07-18 15:39:49'),
(2, 'Sick Leave', 'Medical and health-related leave', 14, 1, '2025-07-18 15:39:49', '2025-07-18 15:39:49'),
(3, 'Maternity Leave', 'Leave for expecting mothers', 90, 1, '2025-07-18 15:39:49', '2025-07-18 15:39:49'),
(4, 'Paternity Leave', 'Leave for new fathers', 14, 1, '2025-07-18 15:39:49', '2025-07-18 15:39:49'),
(5, 'Bereavement Leave', 'Leave for family bereavement', 5, 0, '2025-07-18 15:39:49', '2025-08-18 13:51:38'),
(6, 'Study Leave', 'Leave for educational purposes', 10, 0, '2025-07-18 15:39:49', '2025-08-18 13:51:18'),
(7, 'Unpaid Leave', 'Leave without pay', 0, 0, '2025-07-18 15:39:49', '2025-08-18 13:51:14'),
(8, 'Public Holiday', 'Official public holidays', 0, 0, '2025-07-18 15:39:49', '2025-08-18 13:51:10');

-- --------------------------------------------------------

--
-- Table structure for table `LoginHistory`
--

CREATE TABLE `LoginHistory` (
  `id` int(11) NOT NULL,
  `userId` int(11) DEFAULT NULL,
  `timezone` varchar(191) DEFAULT 'UTC',
  `duration` int(11) DEFAULT NULL,
  `status` int(11) DEFAULT 0,
  `sessionEnd` varchar(191) DEFAULT NULL,
  `sessionStart` varchar(191) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `LoginHistory`
--

INSERT INTO `LoginHistory` (`id`, `userId`, `timezone`, `duration`, `status`, `sessionEnd`, `sessionStart`) VALUES
(2459, 94, 'Africa/Nairobi', 480, 2, '2025-08-27 18:00:00', '2025-08-27T08:15:05.984'),
(2460, 94, 'Africa/Nairobi', 7671, 2, '2025-09-02 18:00:00', '2025-08-28T10:08:06.910'),
(2461, 230, 'Africa/Nairobi', -144, 2, '2025-09-02 18:00:00', '2025-09-02T20:23:24.534569'),
(2462, 157, 'Africa/Nairobi', 0, 2, '2025-09-02T20:28:47.980028', '2025-09-02T20:28:27.918811'),
(2463, 202, 'Africa/Nairobi', 15, 2, '2025-09-02T20:47:18.655835', '2025-09-02T20:31:22.630402'),
(2464, 217, 'Africa/Nairobi', 0, 2, '2025-09-02T20:33:46.431474', '2025-09-02T20:33:37.639974'),
(2465, 209, 'Africa/Nairobi', 0, 2, '2025-09-02T20:34:47.862499', '2025-09-02T20:34:34.595055'),
(2466, 222, 'Africa/Nairobi', 31, 2, '2025-09-02T21:12:21.622358', '2025-09-02T20:40:45.824512'),
(2467, 142, 'Africa/Nairobi', 0, 2, '2025-09-02T20:41:20.325261', '2025-09-02T20:40:57.192617'),
(2468, 170, 'Africa/Nairobi', 0, 2, '2025-09-02T20:44:00.092659', '2025-09-02T20:43:36.491813'),
(2469, 185, 'Africa/Nairobi', 0, 2, '2025-09-02T20:45:43.890205', '2025-09-02T20:45:33.282263'),
(2470, 216, 'Africa/Nairobi', 87, 2, '2025-09-02T22:12:45.166509', '2025-09-02T20:45:39.198449'),
(2471, 211, 'Africa/Nairobi', 0, 2, '2025-09-02T20:56:00.211906', '2025-09-02T20:55:35.861429'),
(2472, 174, 'Africa/Nairobi', 0, 2, '2025-09-02T20:56:10.151727', '2025-09-02T20:56:01.373590'),
(2473, 221, 'Africa/Nairobi', -417, 2, '2025-09-02T14:00:36.694651', '2025-09-02T20:56:56.786233'),
(2474, 192, 'Africa/Nairobi', 0, 2, '2025-09-02T21:35:05.663723', '2025-09-02T21:34:33.980543'),
(2475, 138, 'Africa/Nairobi', 0, 2, '2025-09-02T21:45:08.855659', '2025-09-02T21:45:03.186261'),
(2476, 147, 'Africa/Nairobi', 0, 2, '2025-09-02T22:20:32.568890', '2025-09-02T22:20:14.536688'),
(2477, 190, 'Africa/Nairobi', 57, 2, '2025-09-02T23:22:15.185172', '2025-09-02T22:24:17.954352'),
(2478, 203, 'Africa/Nairobi', 0, 2, '2025-09-02T23:37:53.968241', '2025-09-02T23:37:28.784111'),
(2479, 94, 'Africa/Nairobi', 480, 2, '2025-09-02 18:00:00', '2025-09-02T23:47:33.394'),
(2480, 185, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T00:20:02.910412'),
(2481, 172, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T05:55:27.951637'),
(2482, 235, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:02:43.266960'),
(2483, 182, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:04:42.649473'),
(2484, 142, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:10:43.799439'),
(2485, 165, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:19:59.254719'),
(2486, 197, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:33:08.033857'),
(2487, 162, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:36:43.816332'),
(2488, 219, 'Africa/Nairobi', 0, 2, '2025-09-03T06:47:41.864407', '2025-09-03T06:47:18.041677'),
(2489, 167, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T06:48:27.765692'),
(2490, 175, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:50:18.404075'),
(2491, 154, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T06:54:06.882511'),
(2492, 140, 'Africa/Nairobi', 465, 2, '2025-09-03T14:49:11.746380', '2025-09-03T07:03:36.718520'),
(2493, 160, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:08:55.422525'),
(2494, 203, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:11:05.819752'),
(2495, 153, 'Africa/Nairobi', 340, 2, '2025-09-03T12:52:37.291411', '2025-09-03T07:12:05.923019'),
(2496, 211, 'Africa/Nairobi', 142, 2, '2025-09-03T09:37:12.555539', '2025-09-03T07:14:31.238961'),
(2497, 177, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:18:11.119602'),
(2498, 174, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:21:03.715517'),
(2499, 169, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:21:52.092594'),
(2500, 224, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:23:00.543353'),
(2501, 221, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:23:29.287381'),
(2502, 139, 'Africa/Nairobi', 427, 2, '2025-09-03T14:33:43.005261', '2025-09-03T07:26:15.221764'),
(2503, 155, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T07:27:39.587071'),
(2504, 212, 'Africa/Nairobi', 134, 2, '2025-09-03T09:42:48.170226', '2025-09-03T07:28:10.051368'),
(2505, 150, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:28:27.915610'),
(2506, 156, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T07:28:52.569071'),
(2507, 149, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:29:08.144759'),
(2508, 194, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:30:20.557158'),
(2509, 133, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T07:30:26.173005'),
(2510, 170, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:31:17.656620'),
(2511, 161, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:32:33.413045'),
(2512, 209, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T07:32:35.073227'),
(2513, 214, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:34:54.075664'),
(2514, 192, 'Africa/Nairobi', 169, 2, '2025-09-03T10:25:22.385054', '2025-09-03T07:35:56.381658'),
(2515, 147, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:36:22.447197'),
(2516, 217, 'Africa/Nairobi', 36, 2, '2025-09-03T08:13:16.942632', '2025-09-03T07:37:13.097134'),
(2517, 191, 'Africa/Nairobi', 432, 2, '2025-09-03T14:49:51.211220', '2025-09-03T07:37:47.032202'),
(2518, 151, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:38:22.997089'),
(2519, 184, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:39:44.922244'),
(2520, 152, 'Africa/Nairobi', 449, 2, '2025-09-03T15:15:51.893844', '2025-09-03T07:45:52.510058'),
(2521, 134, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T07:53:50.401275'),
(2522, 222, 'Africa/Nairobi', 190, 2, '2025-09-03T11:09:50.207958', '2025-09-03T07:59:42.864698'),
(2523, 215, 'Africa/Nairobi', 0, 2, '2025-09-03T08:01:58.031278', '2025-09-03T08:01:46.450627'),
(2524, 159, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T08:05:34.330830'),
(2525, 178, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:08:05.921472'),
(2526, 234, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:11:48.720674'),
(2527, 202, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:15:23.433566'),
(2528, 213, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T08:28:52.538890'),
(2529, 138, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:33:40.077524'),
(2530, 157, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T08:37:39.085336'),
(2531, 188, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:40:27.961823'),
(2532, 190, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T08:41:07.990681'),
(2533, 225, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T08:44:31.291371'),
(2534, 216, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T08:55:19.922498'),
(2535, 143, 'Africa/Nairobi', 0, 1, NULL, '2025-09-03T09:03:30.096836'),
(2536, 137, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T09:50:15.888641'),
(2537, 132, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T10:09:13.774643'),
(2538, 144, 'Africa/Nairobi', 449, 2, '2025-09-03T17:39:13.424047', '2025-09-03T10:09:23.742622'),
(2539, 135, 'Africa/Nairobi', 480, 2, '2025-09-03 18:00:00', '2025-09-03T10:16:39.926561'),
(2540, 180, 'Africa/Nairobi', 376, 2, '2025-09-03T17:59:06.953752', '2025-09-03T11:43:00.848921'),
(2541, 223, 'Africa/Nairobi', 0, 2, '2025-09-03T12:29:01.006972', '2025-09-03T12:28:48.122353'),
(2542, 196, 'Africa/Nairobi', 1, 2, '2025-09-03T18:07:19.318731', '2025-09-03T18:06:11.484624'),
(2543, 235, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T05:31:36.173645'),
(2544, 142, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T05:40:07.778730'),
(2545, 182, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:08:24.521473'),
(2546, 165, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:10:33.713456'),
(2547, 172, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:19:47.683742'),
(2548, 139, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:29:52.848752'),
(2549, 197, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:37:29.298665'),
(2550, 135, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:45:09.485013'),
(2551, 211, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:49:08.967462'),
(2552, 132, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:50:25.907699'),
(2553, 154, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T06:58:30.207122'),
(2554, 175, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:00:42.719410'),
(2555, 140, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:01:38.329855'),
(2556, 224, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:01:38.493272'),
(2557, 202, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:09:40.608095'),
(2558, 185, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:10:00.050885'),
(2559, 221, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:11:49.131482'),
(2560, 184, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:11:56.775617'),
(2561, 196, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:15:39.532508'),
(2562, 138, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:18:31.233382'),
(2563, 188, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:26:49.320976'),
(2564, 160, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:26:56.295401'),
(2565, 170, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:28:51.162689'),
(2566, 222, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:29:39.292078'),
(2567, 149, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:30:33.244758'),
(2568, 214, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:31:38.418550'),
(2569, 169, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:33:20.311581'),
(2570, 192, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:34:21.452554'),
(2571, 147, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:34:50.668523'),
(2572, 151, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:36:18.902741'),
(2573, 177, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:40:23.216165'),
(2574, 161, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:40:41.423995'),
(2575, 144, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:42:41.894885'),
(2576, 191, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:43:26.181984'),
(2577, 178, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:46:01.866530'),
(2578, 194, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:46:15.841065'),
(2579, 234, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:52:39.826027'),
(2580, 137, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:49:00.975918'),
(2581, 216, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:53:29.597645'),
(2582, 217, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:55:34.252281'),
(2583, 171, 'Africa/Nairobi', 0, 1, NULL, '2025-09-04T07:56:29.838269');

-- --------------------------------------------------------

--
-- Table structure for table `managers`
--

CREATE TABLE `managers` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `phoneNumber` varchar(20) NOT NULL,
  `managerType` enum('retail','distribution','key_account') NOT NULL,
  `managerTypeId` tinyint(3) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `country` varchar(100) DEFAULT NULL,
  `region_id` int(3) NOT NULL,
  `region` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `managers`
--

INSERT INTO `managers` (`id`, `name`, `email`, `phoneNumber`, `managerType`, `managerTypeId`, `created_at`, `country`, `region_id`, `region`) VALUES
(1, 'Manager', 'bryanotieno09@gmail.com', '0790193625', 'retail', 1, '2025-07-17 23:57:57', 'Kenya', 1, 'Nairobi');

-- --------------------------------------------------------

--
-- Table structure for table `merchandise`
--

CREATE TABLE `merchandise` (
  `id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `category_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 0,
  `description` text DEFAULT NULL,
  `unit_price` decimal(10,2) DEFAULT 0.00,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `merchandise`
--

INSERT INTO `merchandise` (`id`, `name`, `category_id`, `quantity`, `description`, `unit_price`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'tshirts', 1, 0, 'test', 0.00, 1, '2025-08-21 22:42:53', '2025-08-21 22:42:53'),
(2, 'Displays', 2, 0, 'displays', 0.00, 1, '2025-08-22 08:38:03', '2025-08-22 08:38:03');

-- --------------------------------------------------------

--
-- Table structure for table `merchandise_assignments`
--

CREATE TABLE `merchandise_assignments` (
  `id` int(11) NOT NULL,
  `merchandise_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `quantity_assigned` int(11) NOT NULL,
  `date_assigned` date NOT NULL,
  `comment` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `merchandise_assignments`
--

INSERT INTO `merchandise_assignments` (`id`, `merchandise_id`, `staff_id`, `quantity_assigned`, `date_assigned`, `comment`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 2, 3, 5, '2025-08-25', '', 1, '2025-08-25 13:28:19', '2025-08-25 13:28:19'),
(2, 2, 3, 5, '2025-08-25', '', 1, '2025-08-25 13:29:27', '2025-08-25 13:29:27'),
(3, 1, 3, 2, '2025-08-25', '', 1, '2025-08-25 13:30:26', '2025-08-25 13:30:26');

-- --------------------------------------------------------

--
-- Table structure for table `merchandise_categories`
--

CREATE TABLE `merchandise_categories` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `merchandise_categories`
--

INSERT INTO `merchandise_categories` (`id`, `name`, `description`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'T-Shirts', 'tshirts', 1, '2025-08-21 22:36:06', '2025-08-21 22:36:06'),
(2, 'Displays', 'displays', 1, '2025-08-22 08:37:46', '2025-08-22 08:37:46');

-- --------------------------------------------------------

--
-- Table structure for table `merchandise_ledger`
--

CREATE TABLE `merchandise_ledger` (
  `id` int(11) NOT NULL,
  `merchandise_id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `transaction_type` enum('RECEIVE','ISSUE','ADJUSTMENT','TRANSFER') NOT NULL,
  `quantity` int(11) NOT NULL,
  `balance_after` int(11) NOT NULL,
  `reference_id` int(11) DEFAULT NULL,
  `reference_type` enum('STOCK_RECEIPT','STOCK_ISSUE','ADJUSTMENT','TRANSFER') NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `merchandise_ledger`
--

INSERT INTO `merchandise_ledger` (`id`, `merchandise_id`, `store_id`, `transaction_type`, `quantity`, `balance_after`, `reference_id`, `reference_type`, `notes`, `created_by`, `created_at`) VALUES
(1, 2, 1, 'RECEIVE', 3, 14, 2, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-22 08:51:36'),
(2, 1, 1, 'RECEIVE', 3, 23, 1, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-22 08:51:36'),
(3, 1, 1, 'RECEIVE', 20, 43, 1, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-25 12:37:03'),
(4, 2, 1, 'RECEIVE', 2, 16, 2, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-25 12:37:04'),
(5, 1, 1, 'RECEIVE', 20, 63, 1, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-25 12:37:06'),
(6, 2, 1, 'RECEIVE', 2, 18, 2, 'STOCK_RECEIPT', 'Stock received', 4, '2025-08-25 12:37:07');

-- --------------------------------------------------------

--
-- Table structure for table `merchandise_stock`
--

CREATE TABLE `merchandise_stock` (
  `id` int(11) NOT NULL,
  `merchandise_id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 0,
  `received_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `received_by` int(11) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `merchandise_stock`
--

INSERT INTO `merchandise_stock` (`id`, `merchandise_id`, `store_id`, `quantity`, `received_date`, `received_by`, `notes`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 63, '2025-08-21 22:51:25', 4, 'test', 1, '2025-08-21 22:51:25', '2025-08-25 12:37:05'),
(2, 2, 1, 18, '2025-08-22 08:40:24', 4, NULL, 1, '2025-08-22 08:40:24', '2025-08-25 12:37:07');

-- --------------------------------------------------------

--
-- Table structure for table `my_assets`
--

CREATE TABLE `my_assets` (
  `id` int(11) NOT NULL,
  `asset_code` varchar(50) NOT NULL,
  `asset_name` varchar(255) NOT NULL,
  `asset_type` varchar(100) NOT NULL,
  `purchase_date` date NOT NULL,
  `location` varchar(255) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `document_url` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `my_assets`
--

INSERT INTO `my_assets` (`id`, `asset_code`, `asset_name`, `asset_type`, `purchase_date`, `location`, `supplier_id`, `price`, `quantity`, `document_url`, `created_at`, `updated_at`) VALUES
(1, 'test', 'asset 1', 'Furniture', '2025-07-30', 'location', 3, 300.00, 5, '', '2025-07-30 09:47:48', '2025-07-30 10:07:22'),
(2, 'Asset2', 'Asset 2', 'Laptops and Computers', '2025-07-30', 'lo', 1, 300.00, 30, 'https://res.cloudinary.com/otienobryan/image/upload/v1753877294/assets/oaanckcvvnpylh98xpfi.png', '2025-07-30 10:08:20', '2025-08-21 11:50:19'),
(3, '3ww', 'cmop', 'Furniture', '2025-08-21', 'hhh', 3, 500.00, 1, NULL, '2025-08-21 16:25:34', '2025-08-21 16:25:34'),
(4, '4455', 'comp', 'Laptops and Computers', '2025-08-25', 'test', 1, 0.00, 3, 'https://res.cloudinary.com/otienobryan/image/upload/v1756125541/assets/ajepszt9zcqq1prvvagy.jpg', '2025-08-25 12:39:02', '2025-08-25 12:39:02');

-- --------------------------------------------------------

--
-- Table structure for table `my_order`
--

CREATE TABLE `my_order` (
  `id` int(11) NOT NULL,
  `so_number` varchar(20) NOT NULL,
  `client_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `expected_delivery_date` date DEFAULT NULL,
  `subtotal` decimal(15,2) DEFAULT 0.00,
  `tax_amount` decimal(15,2) DEFAULT 0.00,
  `total_amount` decimal(15,2) DEFAULT 0.00,
  `net_price` decimal(11,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `rider_id` int(11) NOT NULL,
  `assigned_at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `status` enum('draft','confirmed','shipped','delivered','cancelled','in payment','paid') DEFAULT 'draft',
  `my_status` tinyint(3) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `my_order`
--

INSERT INTO `my_order` (`id`, `so_number`, `client_id`, `order_date`, `expected_delivery_date`, `subtotal`, `tax_amount`, `total_amount`, `net_price`, `notes`, `created_by`, `created_at`, `updated_at`, `rider_id`, `assigned_at`, `status`, `my_status`) VALUES
(27, 'SO-000001', 2430, '2025-07-22', NULL, 3685.00, 368.50, 4053.50, 0.00, '', 1, '2025-07-30 00:48:18', '2025-07-30 04:23:56', 0, '0000-00-00 00:00:00', 'confirmed', 1);

-- --------------------------------------------------------

--
-- Table structure for table `my_order_items`
--

CREATE TABLE `my_order_items` (
  `id` int(11) NOT NULL,
  `my_order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `tax_amount` decimal(11,2) NOT NULL,
  `total_price` decimal(15,2) NOT NULL,
  `net_price` decimal(11,2) NOT NULL,
  `shipped_quantity` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `my_order_items`
--

INSERT INTO `my_order_items` (`id`, `my_order_id`, `product_id`, `quantity`, `unit_price`, `tax_amount`, `total_price`, `net_price`, `shipped_quantity`) VALUES
(37, 27, 4, 3, 1200.00, 0.00, 3600.00, 0.00, 0),
(38, 27, 7, 1, 85.00, 0.00, 85.00, 0.00, 0);

-- --------------------------------------------------------

--
-- Table structure for table `my_receipts`
--

CREATE TABLE `my_receipts` (
  `id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `comment` text DEFAULT NULL,
  `receipt_date` date NOT NULL,
  `document_path` varchar(500) NOT NULL,
  `original_filename` varchar(255) NOT NULL,
  `file_size` int(11) NOT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `my_receipts`
--

INSERT INTO `my_receipts` (`id`, `supplier_id`, `comment`, `receipt_date`, `document_path`, `original_filename`, `file_size`, `created_by`, `created_at`, `updated_at`) VALUES
(2, 1, 'test', '2025-07-30', 'https://res.cloudinary.com/otienobryan/image/upload/v1753866500/receipts/vgxkfv24lguyo1mzf9gu.png', 'attendance.png', 81043, 1, '2025-07-30 07:08:21', '2025-07-30 07:08:21'),
(3, 1, 'ee', '2025-08-22', 'https://res.cloudinary.com/otienobryan/image/upload/v1755834378/receipts/wriyyn9esv1g5xecqrsv.jpg', 'Gold pouch 3dot.jpg', 81713, 1, '2025-08-22 03:46:19', '2025-08-22 03:46:19');

-- --------------------------------------------------------

--
-- Table structure for table `non_supplies`
--

CREATE TABLE `non_supplies` (
  `reportId` int(11) NOT NULL,
  `productName` varchar(191) DEFAULT NULL,
  `comment` varchar(191) DEFAULT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `clientId` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `productId` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `NoticeBoard`
--

CREATE TABLE `NoticeBoard` (
  `id` int(11) NOT NULL,
  `title` varchar(191) NOT NULL,
  `content` varchar(191) NOT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `updatedAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `countryId` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `NoticeBoard`
--

INSERT INTO `NoticeBoard` (`id`, `title`, `content`, `createdAt`, `updatedAt`, `countryId`) VALUES
(6, 'STOCK OUT', '9000 PUFFS OUT OF STOCK\r\n1. CHIZI MINT\r\n2. PINEAPPLE MANGO MINT\r\n3. STRAWBERRY ICE CREAM\r\n4. SUN KISSED GRAPE\r\n5. BLUE RAZZ\r\n6. FROST APPLE\r\n7. MANGO PEACH.', '2025-06-16 15:23:48.577', '2025-06-16 15:23:48.577', 1),
(7, 'STOCK AVAILABLE 9000 PUFFS', '1. KWI DRAGON STRAWBERRY \r\n2. CARAMEL HAZELNUT\r\n3. ICE SPARKLING ORANGE\r\n4. FRESH LYCHEE\r\n5. CHILLY LEMON\r\n6. DAWA COCKTAIL', '2025-06-16 15:27:23.693', '2025-06-16 15:27:23.693', 1);

-- --------------------------------------------------------

--
-- Table structure for table `notices`
--

CREATE TABLE `notices` (
  `id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `content` text NOT NULL,
  `country_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` tinyint(3) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `notices`
--

INSERT INTO `notices` (`id`, `title`, `content`, `country_id`, `created_at`, `status`) VALUES
(6, 'product back to market', '3k most welcome flavors \n9k most welcome flavors', 1, '2025-08-19 10:39:49', 0),
(7, 'new', 'notice', 1, '2025-08-19 21:03:48', 0);

-- --------------------------------------------------------

--
-- Table structure for table `outlet_categories`
--

CREATE TABLE `outlet_categories` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `outlet_categories`
--

INSERT INTO `outlet_categories` (`id`, `name`) VALUES
(1, 'Retail'),
(2, 'Key Accounts'),
(3, 'Distribution');

-- --------------------------------------------------------

--
-- Table structure for table `out_of_office_requests`
--

CREATE TABLE `out_of_office_requests` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `reason` varchar(255) NOT NULL,
  `comment` text DEFAULT NULL,
  `status` enum('pending','approved','declined') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `title` varchar(255) NOT NULL DEFAULT 'Out of Office Request'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `id` int(11) NOT NULL,
  `payment_number` varchar(20) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `purchase_order_id` int(11) DEFAULT NULL,
  `payment_date` date NOT NULL,
  `payment_method` enum('cash','check','bank_transfer','credit_card') NOT NULL,
  `reference_number` varchar(50) DEFAULT NULL,
  `amount` decimal(15,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `account_id` int(11) DEFAULT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `status` enum('in pay','confirmed') DEFAULT 'in pay'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`id`, `payment_number`, `supplier_id`, `purchase_order_id`, `payment_date`, `payment_method`, `reference_number`, `amount`, `notes`, `created_by`, `created_at`, `updated_at`, `account_id`, `reference`, `status`) VALUES
(1, 'PAY-2-1751822937737', 2, NULL, '2025-07-06', 'cash', NULL, 3719.88, '', 1, '2025-07-06 15:28:55', '2025-07-12 08:17:32', 1, '', 'confirmed'),
(2, 'PAY-2-1751822957518', 2, NULL, '2025-07-06', 'cash', NULL, 300.00, '', 1, '2025-07-06 15:29:15', '2025-07-06 15:40:38', 1, '', 'confirmed'),
(3, 'PAY-2-1751823164134', 2, NULL, '2025-07-06', 'cash', NULL, 400.00, '', 1, '2025-07-06 15:32:42', '2025-07-06 15:45:15', 1, '', 'confirmed'),
(4, 'PAY-2-1751823340861', 2, NULL, '2025-07-06', 'check', NULL, 370.00, '', 1, '2025-07-06 15:35:39', '2025-07-06 15:40:00', 1, '', 'confirmed'),
(5, 'PAY-3-1752315446955', 3, NULL, '2025-07-12', 'check', NULL, 200.00, 'nn', 1, '2025-07-12 08:17:26', '2025-07-12 08:17:36', 24, '', 'confirmed'),
(6, 'PAY-3-1752401562561', 3, NULL, '2025-07-13', 'credit_card', NULL, 200.00, '', 1, '2025-07-13 08:12:39', '2025-07-13 08:13:27', 29, '', 'confirmed'),
(7, 'PAY-3-1752402940212', 3, NULL, '2025-07-13', 'credit_card', NULL, 120.00, '', 1, '2025-07-13 08:35:37', '2025-07-13 08:36:29', 23, '', 'confirmed'),
(8, 'PAY-3-1752403292029', 3, NULL, '2025-07-13', 'cash', NULL, 200.00, '', 1, '2025-07-13 08:41:29', '2025-07-13 08:41:36', 23, '', 'confirmed'),
(9, 'PAY-3-1754744593126-', 3, 7, '2025-08-09', 'bank_transfer', NULL, 4.00, '', 1, '2025-08-09 13:03:12', '2025-08-09 13:03:12', 23, 'test', 'confirmed'),
(10, 'PAY-3-1754744747384-', 3, 6, '2025-08-09', 'bank_transfer', NULL, 100.00, '', 1, '2025-08-09 13:05:46', '2025-08-09 13:05:46', 21, 'test', 'confirmed');

-- --------------------------------------------------------

--
-- Table structure for table `payroll_history`
--

CREATE TABLE `payroll_history` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `pay_date` date NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `payroll_history`
--

INSERT INTO `payroll_history` (`id`, `staff_id`, `pay_date`, `amount`, `notes`, `created_at`) VALUES
(3, 3, '2025-07-12', 40000.00, NULL, '2025-07-12 16:27:06'),
(4, 2, '2025-07-12', 45000.00, NULL, '2025-07-12 17:30:17'),
(5, 3, '2025-07-13', 40000.00, NULL, '2025-07-12 17:35:28'),
(6, 1, '2025-08-10', 10.00, NULL, '2025-08-10 10:41:54'),
(7, 2, '2025-08-10', 45000.00, NULL, '2025-08-10 10:41:54'),
(8, 3, '2025-08-10', 40000.00, NULL, '2025-08-10 10:41:54'),
(9, 4, '2025-08-10', 45000.00, NULL, '2025-08-10 10:41:54'),
(10, 5, '2025-08-10', 30000.00, NULL, '2025-08-10 10:41:54'),
(11, 6, '2025-08-10', 35000.00, NULL, '2025-08-10 10:41:54'),
(12, 7, '2025-08-10', 40000.00, NULL, '2025-08-10 10:41:54'),
(13, 8, '2025-08-10', 0.00, NULL, '2025-08-10 10:41:54'),
(14, 9, '2025-08-10', 0.00, NULL, '2025-08-10 10:41:54');

-- --------------------------------------------------------

--
-- Table structure for table `Product`
--

CREATE TABLE `Product` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `category_id` int(11) NOT NULL,
  `category` varchar(191) NOT NULL,
  `unit_cost` decimal(11,2) NOT NULL,
  `description` varchar(191) DEFAULT NULL,
  `currentStock` int(11) DEFAULT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `updatedAt` datetime(3) NOT NULL,
  `clientId` int(11) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `unit_cost_ngn` decimal(11,2) DEFAULT NULL,
  `unit_cost_tzs` decimal(11,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Product`
--

INSERT INTO `Product` (`id`, `name`, `category_id`, `category`, `unit_cost`, `description`, `currentStock`, `createdAt`, `updatedAt`, `clientId`, `image`, `unit_cost_ngn`, `unit_cost_tzs`) VALUES
(1, 'Carlifonia Strawberry 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-06 09:09:37.260', '2025-06-25 17:05:21.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_1_1750863921.jpg', 90.00, 4130.00),
(2, 'Australian Ice Mango 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-06 09:10:00.366', '2025-06-25 16:59:30.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_2_1750863570.jpg', 90.00, 4130.00),
(3, 'Ice Passion Fruit 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-07 05:59:00.405', '2025-06-25 17:04:30.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_3_1750863870.jpg', 90.00, 4130.00),
(4, 'Pineapple Mint 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-07 05:59:55.441', '2025-06-25 17:04:50.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_4_1750863890.jpg', 90.00, 4130.00),
(5, 'Pina colada 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-07 06:00:13.389', '2025-06-25 17:05:34.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_5_1750863934.jpg', 90.00, 4130.00),
(6, 'Ice Watermelon Bliss 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-07 06:00:45.242', '2025-06-25 17:05:06.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_6_1750863906.jpg', 90.00, 4130.00),
(7, 'Minty Snow 3000puffs', 1, '3000 puffs', 200.00, '', NULL, '2025-05-07 06:01:02.942', '2025-06-25 17:04:06.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_7_1750863846.jpg', 90.00, 4130.00),
(8, 'Chizi Mint 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:01:41.401', '2025-06-25 17:03:44.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_8_1750863824.jpg', 90.00, 4130.00),
(9, 'Dawa Cocktail 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:01:54.911', '2025-06-25 17:03:29.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_9_1750863809.jpg', 90.00, 4130.00),
(10, 'Caramel Hazelnut 9000 puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:02:09.187', '2025-06-25 16:59:52.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_10_1750863592.jpg', 90.00, 4130.00),
(11, 'Kiwi Dragon Strawberry 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:02:54.414', '2025-06-25 17:00:07.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_11_1750863607.jpg', 90.00, 4130.00),
(12, 'Fresh Lychee 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:03:06.141', '2025-06-25 17:00:21.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_12_1750863621.jpg', 90.00, 4130.00),
(13, 'Ice Sparkling Orange 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:03:34.833', '2025-06-25 17:00:44.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_13_1750863644.jpg', 90.00, 4130.00),
(14, 'Pineapple Mango Mint 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:03:48.958', '2025-06-25 17:01:03.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_14_1750863663.jpg', 90.00, 4130.00),
(15, 'Blue Razz 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:04:00.932', '2025-06-25 17:01:15.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_15_1750863675.jpg', 90.00, 4130.00),
(16, 'Chilly Lemon Soda 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:04:16.580', '2025-06-25 17:01:30.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_16_1750863690.jpg', 90.00, 4130.00),
(17, 'Strawberry ice cream 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-07 06:04:29.395', '2025-06-25 17:01:54.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_17_1750863714.jpg', 90.00, 4130.00),
(18, 'Cool Mint 3dot', 4, 'Gold pouch 3dot ', 200.00, '', NULL, '2025-05-07 06:04:40.846', '2025-06-25 17:06:51.000', NULL, 'https://citlogisticssystems.com/woosh/admin//upload/products/product_18_1750864011.jpg', 90.00, 4130.00),
(19, 'Cool Mint 5dot', 5, 'Gold pouch 5dot', 200.00, NULL, NULL, '2025-05-07 06:04:54.227', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(20, 'Frost Apple 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-20 05:21:40.620', '2025-06-25 17:24:15.000', NULL, '', 90.00, 4130.00),
(21, 'Mango Peach 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-20 05:25:34.421', '2025-06-25 17:23:53.000', NULL, '', 90.00, 4130.00),
(22, 'Sun Kissed 9000puffs', 3, '9000 puffs', 200.00, '', NULL, '2025-05-20 05:26:43.146', '2025-06-25 17:24:38.000', NULL, '', 90.00, 4130.00),
(23, 'Strawberry Mint 3 dot', 4, 'Gold pouch 3dot ', 200.00, NULL, NULL, '2025-05-20 05:32:01.035', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(24, 'Sweet Mint 3dot', 4, 'Gold pouch 3dot ', 200.00, NULL, NULL, '2025-05-20 05:32:34.605', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(25, 'Citrus Mint 3dot', 4, 'Gold pouch 3dot ', 200.00, NULL, NULL, '2025-05-20 05:33:06.714', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(26, 'Mix Berry mint 3dot', 4, 'Gold pouch 3dot ', 200.00, NULL, NULL, '2025-05-20 05:33:39.064', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(27, 'Strawberry Mint 5 dot', 5, 'Gold pouch 5dot', 200.00, NULL, NULL, '2025-05-20 05:35:23.670', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(28, 'Sweet Mint 5dot', 5, 'Gold pouch 5dot', 200.00, NULL, NULL, '2025-05-20 05:35:55.672', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(29, 'Citrus Mint 5dot', 5, 'Gold pouch 5dot', 200.00, NULL, NULL, '2025-05-20 05:36:52.357', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00),
(30, 'Mix Berry Mint 5dot', 5, 'Gold pouch 5dot', 200.00, NULL, NULL, '2025-05-20 05:37:22.148', '2025-05-07 06:04:54.227', NULL, '', 90.00, 4130.00);

-- --------------------------------------------------------

--
-- Table structure for table `ProductExpiryReport`
--

CREATE TABLE `ProductExpiryReport` (
  `id` int(11) NOT NULL,
  `journeyPlanId` int(11) NOT NULL,
  `clientId` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `productName` varchar(255) NOT NULL,
  `productId` int(11) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `expiryDate` date DEFAULT NULL,
  `batchNumber` varchar(100) DEFAULT NULL,
  `comments` text DEFAULT NULL,
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `ProductExpiryReport`
--

INSERT INTO `ProductExpiryReport` (`id`, `journeyPlanId`, `clientId`, `userId`, `productName`, `productId`, `quantity`, `expiryDate`, `batchNumber`, `comments`, `createdAt`, `updatedAt`) VALUES
(1, 8025, 10733, 94, 'Coconut 100ml', 81, 12, '2025-08-30', '12345', 'test', '2025-08-27 07:31:32', '2025-08-27 07:31:32'),
(2, 8033, 10653, 129, 'Coconut 150ml', 82, 20, '2025-10-10', NULL, 'test', '2025-09-02 14:34:19', '2025-09-02 14:34:19'),
(3, 8045, 10730, 138, 'KCC Gold Crown 500ml', 10, 13, '2025-10-04', NULL, NULL, '2025-09-03 06:26:19', '2025-09-03 06:26:19'),
(4, 8065, 10748, 202, 'Coconut 150ml', 82, 12, '2025-10-03', NULL, 'not', '2025-09-03 07:46:43', '2025-09-03 07:46:43');

-- --------------------------------------------------------

--
-- Table structure for table `ProductReport`
--

CREATE TABLE `ProductReport` (
  `reportId` int(11) NOT NULL,
  `productName` varchar(191) DEFAULT NULL,
  `quantity` int(11) DEFAULT NULL,
  `comment` varchar(191) DEFAULT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `clientId` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `productId` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `ProductReport`
--

INSERT INTO `ProductReport` (`reportId`, `productName`, `quantity`, `comment`, `createdAt`, `clientId`, `id`, `userId`, `productId`) VALUES
(0, 'Coconut 100ml', 20, NULL, '2025-08-27 09:28:52.806', 10733, 64915, 94, 81),
(0, 'Coconut 100ml', 1, NULL, '2025-08-27 09:29:14.322', 10733, 64916, 94, 81),
(0, 'Coconut 150ml', 1, NULL, '2025-08-27 09:29:14.748', 10733, 64917, 94, 82),
(0, 'Coconut 250ml', 1, NULL, '2025-08-27 09:29:15.217', 10733, 64918, 94, 84),
(0, 'KCC Fat Free  500ml', 1, NULL, '2025-08-27 09:29:15.615', 10733, 64919, 94, 119),
(0, 'Coconut 100ml', 1, NULL, '2025-08-27 20:35:24.374', 10653, 64920, 94, 81),
(0, 'Coconut 150ml', 1, NULL, '2025-08-27 20:35:25.680', 10653, 64921, 94, 82),
(0, 'KCC Dried WM Powder Satchet 250g', 20, NULL, '2025-09-02 16:33:36.672', 10653, 64922, 129, 113),
(0, 'Coconut 150ml', 30, NULL, '2025-09-02 16:33:38.078', 10653, 64923, 129, 82),
(0, 'Coconut 250ml', 0, NULL, '2025-09-03 07:44:00.115', 10728, 64924, 178, 84),
(0, 'Coconut 100ml', 0, NULL, '2025-09-03 08:17:16.775', 10730, 64925, 138, 81),
(0, 'KCC Ghee 1kg', 13, NULL, '2025-09-03 08:19:38.434', 10730, 64926, 138, 12),
(0, 'KCC Ghee 500g', 18, NULL, '2025-09-03 08:19:40.153', 10730, 64927, 138, 18),
(0, 'KCC Gold Crown 500ml', 15, NULL, '2025-09-03 08:19:41.521', 10730, 64928, 138, 10),
(0, 'KCC Mala bottle  1 litre', 6, NULL, '2025-09-03 08:19:42.896', 10730, 64929, 138, 105),
(0, 'KCC Mala Pouch 500ml', 23, NULL, '2025-09-03 08:19:44.255', 10730, 64930, 138, 106),
(0, 'Coconut 100ml', 0, NULL, '2025-09-03 09:43:12.341', 10748, 64931, 202, 81);

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `product_code` varchar(20) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `category_id` int(11) NOT NULL,
  `category` varchar(50) DEFAULT NULL,
  `unit_of_measure` varchar(20) DEFAULT 'PCS',
  `cost_price` decimal(10,2) DEFAULT 0.00,
  `selling_price` decimal(10,2) DEFAULT 0.00,
  `tax_type` enum('16%','zero_rated','exempted') DEFAULT '16%',
  `reorder_level` int(11) DEFAULT 0,
  `current_stock` int(11) DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `image_url` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `product_code`, `product_name`, `description`, `category_id`, `category`, `unit_of_measure`, `cost_price`, `selling_price`, `tax_type`, `reorder_level`, `current_stock`, `is_active`, `created_at`, `updated_at`, `image_url`) VALUES
(1, 'KCC Taifa 250ml', 'KCC Taifa 250ml', NULL, 1, 'Fresh Milk', 'PCS', 0.00, 1200.00, '16%', 10, 0, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(2, 'Gold Crown', 'Gold Crown Standard Bottle 1 litre', NULL, 1, 'Fresh Milk', 'PCS', 15.00, 25.00, '16%', 50, 100, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(3, 'Gold Crown23', 'Gold Crown Standard Bottle 5 litres', NULL, 1, 'Fresh Milk', 'PCS', 0.00, 95.00, '16%', 20, 34, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(4, 'NKCC Proc', 'NKCC Processed Cheese & Tomato 120g', NULL, 1, 'Cheese', 'PCS', 5.00, 12.00, '16%', 100, 200, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(5, 'Unsalted Ply 500g', 'Unsalted Ply 500g', NULL, 1, 'KCC Butter', 'PCS', 25.00, 45.00, '16%', 15, 27, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(6, 'Salted Tubs 500g', 'Salted Tubs 500g', NULL, 1, 'KCC Butter', 'PCS', 35.00, 65.00, '16%', 25, 40, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(7, 'Salted Tubs 250g', 'Salted Tubs 250g', NULL, 1, 'KCC Butter', 'PCS', 45.00, 85.00, '16%', 30, 55, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(8, 'KCC Gold Crown TCA 2', 'KCC Gold Crown TCA 200ml', NULL, 1, 'Long Life', 'PCS', 0.00, 35.00, '16%', 40, 75, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(9, 'KCC Taifa TFA 500ml', 'KCC Taifa TFA 500ml', NULL, 1, 'Long Life', 'PCS', 0.00, 99.00, '16%', 20, 19, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(10, 'KCC Gold Crown', 'KCC Gold Crown 500ml', NULL, 1, 'Fresh Milk', 'PCS', 30.00, 55.00, '16%', 25, 32, 1, '2025-07-06 08:32:52', '2025-08-26 17:14:19', ''),
(11, 'Unsalted Tubs 250g', 'Unsalted Tubs 250g', NULL, 1, 'KCC Butter', 'PCS', 400.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:45:16', '2025-08-26 17:14:19', ''),
(12, 'KCC Ghee 1kg', 'KCC Ghee 1kg', NULL, 3, 'Ghee', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:53:14', '2025-08-26 17:14:19', ''),
(13, 'KCC Taifa 500ml', 'KCC Taifa 500ml', NULL, 3, 'Fresh Milk', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:53:38', '2025-08-26 17:14:19', ''),
(14, 'KCC Gold Crown TBA V', 'KCC Gold Crown TBA VP 1 litre', NULL, 3, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:53:59', '2025-08-26 17:14:19', ''),
(15, 'KCC Taifa TFA 250ml', 'KCC Taifa TFA 250ml', NULL, 3, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:54:21', '2025-08-26 17:14:19', ''),
(16, 'Unsalted Tubs 500g', 'Unsalted Tubs 500g', NULL, 3, 'KCC Butter', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:54:48', '2025-08-26 17:14:19', ''),
(17, 'KCC UHT 250ml', 'KCC UHT 250ml', NULL, 3, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:55:19', '2025-08-26 17:14:19', ''),
(18, 'KCC Ghee 500g', 'KCC Ghee 500g', NULL, 3, 'Ghee', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:55:42', '2025-08-26 17:14:19', ''),
(19, 'Gold Crown Standard', 'Gold Crown Standard Bottle 2 litre', NULL, 3, 'Fresh Milk', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:56:00', '2025-08-26 17:14:19', ''),
(20, 'KCC UHT VP 1 litre', 'KCC UHT VP 1 litre', NULL, 3, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-07-17 18:56:23', '2025-08-26 17:14:19', ''),
(21, 'NKCC Proces', 'NKCC Processed Cheese 120g', NULL, 5, 'Cheese', 'PCS', 300.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:17:37', '2025-08-26 17:14:19', ''),
(22, 'NKCC Rindless5', 'NKCC Rindless Cheddar Cheese 500g', NULL, 5, 'Cheese', 'PCS', 300.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:18:19', '2025-08-26 17:14:19', ''),
(23, 'KCC UHT  1 litre', 'KCC UHT  1 litre', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:19:04', '2025-08-26 17:14:19', ''),
(24, 'Lactose Free TFA 500', 'Lactose Free TFA 500ml', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:19:34', '2025-08-26 17:14:19', ''),
(25, 'KCC Green ESL 450ml', 'KCC Green ESL 450ml', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:20:04', '2025-08-26 17:14:19', ''),
(26, 'NKCC Rind', 'NKCC Rindless Cheddar Cheese 1kg', NULL, 4, 'Cheese', 'PCS', 300.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:21:37', '2025-08-26 17:14:19', ''),
(27, 'NKCC Rindles6', 'NKCC Rindless Cheddar Cheese 250g', NULL, 4, 'Cheese', 'PCS', 300.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:21:59', '2025-08-26 17:14:19', ''),
(28, 'KCC UHT 500ml', 'KCC UHT 500ml', NULL, 4, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:22:27', '2025-08-26 17:14:19', ''),
(29, 'Lactose Free 250ml', 'Lactose Free 250ml', NULL, 4, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:22:50', '2025-08-26 17:14:19', ''),
(30, 'KCC Green TFA', 'KCC Green TFA 500ml', NULL, 4, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-03 07:23:13', '2025-08-26 17:14:19', ''),
(31, 'KCC Gold Crown ESL 5', 'KCC Gold Crown ESL 500ml', NULL, 8, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:48:30', '2025-08-26 17:14:19', ''),
(32, 'KCC Ghee 2kg', 'KCC Ghee 2kg', NULL, 8, 'Ghee', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:48:56', '2025-08-26 17:14:19', ''),
(33, 'KCC Gold Crown TBA 1', 'KCC Gold Crown TBA 1 Litre', NULL, 8, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:52:31', '2025-08-26 17:14:19', ''),
(34, 'Salted Ply 500g', 'Salted Ply 500g', NULL, 8, 'KCC Butter', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:56:57', '2025-08-26 17:14:19', ''),
(35, 'Lactose Free  1 litr', 'Lactose Free  1 litre', NULL, 8, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:57:28', '2025-08-26 17:14:19', ''),
(36, 'KCC Green ', 'KCC Green 500ml', NULL, 8, 'Fresh Milk', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:58:10', '2025-08-26 17:14:19', ''),
(37, 'KCC Greentr', 'KCC Green TR 500ml', NULL, 8, 'Fresh Milk', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:58:33', '2025-08-26 17:14:19', ''),
(38, 'KCC Green TCA 200ml', 'KCC Green TCA 200ml', NULL, 8, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 02:59:17', '2025-08-26 17:14:19', ''),
(39, 'KCC Fresh Kabambe 10', 'KCC Fresh Kabambe 100ml', NULL, 8, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:00:04', '2025-08-26 17:14:19', ''),
(40, 'KCC Ghee 3kg', 'KCC Ghee 3kg', NULL, 8, 'Ghee', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:00:26', '2025-08-26 17:14:19', ''),
(41, 'Gold Crown Stand', 'Gold Crown Standard Bottle 3 litre', NULL, 8, 'Fresh Milk', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:00:47', '2025-08-26 17:14:19', ''),
(42, 'Lactose Free 6 pack ', 'Lactose Free 6 pack 250ml', NULL, 9, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:19:06', '2025-08-26 17:14:19', ''),
(43, 'NKCC Rindless Chedda', 'NKCC Rindless Cheddar Cheese 150g', NULL, 9, 'Cheese', 'PCS', 200.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:19:50', '2025-08-26 17:14:19', ''),
(44, 'KCC Gold Crown TFA 5', 'KCC Gold Crown TFA 500ml', NULL, 9, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-04 03:20:10', '2025-08-26 17:14:19', ''),
(59, 'Lactose Free V/pack ', 'Lactose Free V/pack 1 litre', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:24:16', '2025-08-26 17:14:19', ''),
(60, 'KCC Fat Free  500ml', 'KCC Fat Free  500ml', NULL, 4, 'Fresh Milk', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:24:37', '2025-08-26 17:14:19', ''),
(61, 'KCC Fat Free  1L', 'KCC Fat Free  1L', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:25:00', '2025-08-26 17:14:19', ''),
(62, 'KCC Shake Singles 25', 'KCC Shake Singles 250ml', NULL, 9, 'Shakes', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:25:28', '2025-08-26 17:14:19', ''),
(63, 'KCC SHAKE 6 PACK -AS', 'KCC SHAKE 6 PACK -ASSORTED 250ml', NULL, 9, 'Shakes', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:25:49', '2025-08-26 17:14:19', ''),
(64, 'KCC SHAKE 6 PACK  25', 'KCC SHAKE 6 PACK  250ml', NULL, 9, 'Shakes', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:26:12', '2025-08-26 17:14:19', ''),
(65, 'Vanilla 100ml', 'Vanilla 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:26:38', '2025-08-26 17:14:19', ''),
(66, 'Vanilla 150ml', 'Vanilla 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:26:57', '2025-08-26 17:14:19', ''),
(67, 'Vanilla 250ml', 'Vanilla 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:27:16', '2025-08-26 17:14:19', ''),
(68, 'Vanilla 500ml', 'Vanilla 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:27:35', '2025-08-26 17:14:19', ''),
(69, 'Strawberry 100ml', 'Strawberry 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:27:55', '2025-08-26 17:14:19', ''),
(70, 'Strawberry 150ml', 'Strawberry 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:28:13', '2025-08-26 17:14:19', ''),
(71, 'Strawberry 250ml', 'Strawberry 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:28:32', '2025-08-26 17:14:19', ''),
(72, 'Strawberry 500ml', 'Strawberry 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:28:52', '2025-08-26 17:14:19', ''),
(73, 'Mango 100ml', 'Mango 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:29:17', '2025-08-26 17:14:19', ''),
(74, 'Mango 150ml', 'Mango 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:29:37', '2025-08-26 17:14:19', ''),
(75, 'Mango 250ml', 'Mango 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:29:55', '2025-08-26 17:14:19', ''),
(76, 'Mango 500ml', 'Mango 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:30:13', '2025-08-26 17:14:19', ''),
(77, 'Natural 100ml', 'Natural 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:30:32', '2025-08-26 17:14:19', ''),
(78, 'Natural 150ml', 'Natural 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:30:51', '2025-08-26 17:14:19', ''),
(79, 'Natural 250ml', 'Natural 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:31:09', '2025-08-26 17:14:19', ''),
(80, 'Natural 500ml', 'Natural 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:31:29', '2025-08-26 17:14:19', ''),
(81, 'Coconut 100ml', 'Coconut 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:31:57', '2025-08-26 17:14:19', ''),
(82, 'Coconut 150ml', 'Coconut 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:32:15', '2025-08-26 17:14:19', ''),
(84, 'Coconut 250ml', 'Coconut 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:32:57', '2025-08-26 17:14:19', ''),
(85, 'Coconut 500ml', 'Coconut 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:33:13', '2025-08-26 17:14:19', ''),
(86, 'Pineapple 100ml', 'Pineapple 100ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:33:30', '2025-08-26 17:14:19', ''),
(87, 'Pineapple 150ml', 'Pineapple 150ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:33:48', '2025-08-26 17:14:19', ''),
(88, 'Pineapple 250ml', 'Pineapple 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:34:07', '2025-08-26 17:14:19', ''),
(89, 'Pineapple 500ml', 'Pineapple 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:34:24', '2025-08-26 17:14:19', ''),
(90, 'La yoghurt Vanilla 2', 'La yoghurt Vanilla 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:34:55', '2025-08-26 17:14:19', ''),
(91, 'La yoghurt Strawberr', 'La yoghurt Strawberry 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:35:13', '2025-08-26 17:14:19', ''),
(92, 'La yoghurt Coconut 2', 'La yoghurt Coconut 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:35:29', '2025-08-26 17:14:19', ''),
(93, 'La yoghurt Pineapple', 'La yoghurt Pineapple 250ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:35:48', '2025-08-26 17:14:19', ''),
(94, 'La yoghurt Vanilla 5', 'La yoghurt Vanilla 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:36:06', '2025-08-26 17:14:19', ''),
(97, 'La yoghurt Coconut 5', 'La yoghurt Coconut 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:36:45', '2025-08-26 17:14:19', ''),
(99, 'La yoghurt Pineae 50', 'La yoghurt Pineapple 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:37:29', '2025-08-26 17:14:19', ''),
(100, 'La yoghurt Stra', 'La yoghurt Strawberry 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:37:52', '2025-08-26 17:14:19', ''),
(101, 'Yoghurt Tr Vanilla 5', 'Yoghurt Tr Vanilla 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:38:47', '2025-08-26 17:14:19', ''),
(102, 'KCC Mala TR 500ml', 'KCC Mala TR 500ml', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:39:16', '2025-08-26 17:14:19', ''),
(103, 'KCC Mala TR 1 litre', 'KCC Mala TR 1 litre', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:39:34', '2025-08-26 17:14:19', ''),
(104, 'KCC Mala bottle  500', 'KCC Mala bottle  500ml', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:39:55', '2025-08-26 17:14:19', ''),
(105, 'KCC Mala bottle  1 l', 'KCC Mala bottle  1 litre', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:40:12', '2025-08-26 17:14:19', ''),
(106, 'KCC Mala Pouch 500ml', 'KCC Mala Pouch 500ml', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:40:31', '2025-08-26 17:14:19', ''),
(107, 'KCC Sweetened Mala 5', 'KCC Sweetened Mala 500ml', NULL, 11, 'Mala', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:40:50', '2025-08-26 17:14:19', ''),
(108, 'KCC Dried WM Powder ', 'KCC Dried WM Powder Tin 2kg', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:41:14', '2025-08-26 17:14:19', ''),
(110, 'KCC Dried WM3', 'KCC Dried WM Powder Tin 1kg', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:41:46', '2025-08-26 17:14:19', ''),
(111, 'KCC Dried WM34', 'KCC Dried WM Powder Tin 500g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:42:17', '2025-08-26 17:14:19', ''),
(112, 'KCC Dried WM44', 'KCC Dried WM Powder Satchet 500g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:42:41', '2025-08-26 17:14:19', ''),
(113, 'KCC Dried W2', 'KCC Dried WM Powder Satchet 250g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:43:04', '2025-08-26 17:14:19', ''),
(114, 'KCC Dried 2', 'KCC Dried WM Powder Satchet 100g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:43:28', '2025-08-26 17:14:19', ''),
(115, 'KCC Dried W002', 'KCC Dried WM Powder Satchet 50g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:43:50', '2025-08-26 17:14:19', ''),
(116, 'KCC Skimmed Po', 'KCC Skimmed Powder Satchet 500g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:44:11', '2025-08-26 17:14:19', ''),
(117, 'KCC Skimmed ', 'KCC Skimmed Powder Satchet 250g', NULL, 12, 'Milk Powder', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:44:42', '2025-08-26 17:14:19', ''),
(118, 'Salted Pl3', 'Salted Ply 250g', NULL, 8, 'KCC Butter', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:50:48', '2025-08-26 17:14:19', ''),
(119, 'KCC Fate', 'KCC Fat Free  500ml', NULL, 5, 'Long Life', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 16:58:25', '2025-08-26 17:14:19', ''),
(120, 'Yoghurt T3', 'Yoghurt Tr Strawberry 500ml', NULL, 10, 'Yoghurt', 'PCS', 0.00, 0.00, '16%', 0, 0, 1, '2025-08-26 17:04:12', '2025-08-26 17:14:19', '');

-- --------------------------------------------------------

--
-- Table structure for table `purchase_orders`
--

CREATE TABLE `purchase_orders` (
  `id` int(11) NOT NULL,
  `po_number` varchar(20) NOT NULL,
  `invoice_number` varchar(200) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `expected_delivery_date` date DEFAULT NULL,
  `status` enum('draft','sent','received','cancelled') DEFAULT 'draft',
  `subtotal` decimal(15,2) DEFAULT 0.00,
  `tax_amount` decimal(15,2) DEFAULT 0.00,
  `total_amount` decimal(15,2) DEFAULT 0.00,
  `amount_paid` decimal(11,2) NOT NULL,
  `balance` decimal(11,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `purchase_orders`
--

INSERT INTO `purchase_orders` (`id`, `po_number`, `invoice_number`, `supplier_id`, `order_date`, `expected_delivery_date`, `status`, `subtotal`, `tax_amount`, `total_amount`, `amount_paid`, `balance`, `notes`, `created_by`, `created_at`, `updated_at`) VALUES
(1, 'PO-000001', '', 3, '2025-07-06', '2025-07-10', 'sent', 40000.00, 4000.00, 44000.00, 0.00, 0.00, NULL, 1, '2025-07-06 08:33:39', '2025-07-17 11:36:31'),
(2, 'PO-000002', '', 1, '2025-07-03', '2025-07-05', 'cancelled', 200.00, 20.00, 220.00, 0.00, 0.00, '', 1, '2025-07-06 09:20:23', '2025-07-16 15:08:43'),
(3, 'PO-TEST-001', '', 1, '2025-07-06', '2025-07-13', 'received', 1000.00, 100.00, 1100.00, 0.00, 0.00, 'Test purchase order for receiving functionality', 1, '2025-07-06 09:30:46', '2025-07-06 09:52:07'),
(4, 'PO-000004', '', 3, '2025-07-06', '2025-07-06', 'received', 200.00, 20.00, 220.00, 0.00, 0.00, NULL, 1, '2025-07-06 09:53:49', '2025-07-06 14:48:46'),
(5, 'PO-000005', '', 2, '2025-07-06', '2025-07-07', 'received', 3719.88, 371.99, 4091.87, 0.00, 0.00, NULL, 1, '2025-07-06 15:04:13', '2025-07-06 15:05:26'),
(6, 'PO-000006', '', 3, '2025-07-07', '2025-07-07', 'received', 2000.00, 200.00, 2200.00, 0.00, 0.00, NULL, 1, '2025-07-07 17:56:33', '2025-07-07 18:00:58'),
(7, 'PO-000007', '', 3, '2025-07-07', '2025-07-08', 'received', 4.00, 0.40, 4.40, 0.00, 0.00, NULL, 1, '2025-07-07 18:12:39', '2025-07-07 18:13:24'),
(8, 'PO-000008', '', 1, '2025-07-12', NULL, 'received', 600.00, 60.00, 660.00, 0.00, 0.00, NULL, 1, '2025-07-12 06:45:53', '2025-07-12 07:00:08'),
(9, 'PO-000009', '', 1, '2025-07-14', '2025-07-14', 'received', 299.98, 30.00, 329.98, 0.00, 0.00, NULL, 1, '2025-07-14 07:14:27', '2025-07-14 07:55:09'),
(10, 'PO-000010', '', 1, '2025-07-14', '2025-07-14', 'received', 2000.00, 200.00, 2200.00, 0.00, 0.00, NULL, 1, '2025-07-14 07:57:32', '2025-07-14 07:58:08'),
(11, 'PO-000011', '', 1, '2025-07-22', '2025-07-22', 'received', 3000.00, 300.00, 3300.00, 0.00, 0.00, NULL, 1, '2025-07-22 05:55:43', '2025-07-22 09:31:33'),
(12, 'PO-000012', '', 1, '2025-07-28', '2025-07-28', 'received', 200.00, 20.00, 220.00, 0.00, 0.00, NULL, 1, '2025-07-28 10:25:39', '2025-07-28 10:26:52'),
(13, 'PO-000013', '', 3, '2025-08-01', NULL, 'sent', 30002.00, 3000.20, 33002.20, 0.00, 0.00, NULL, 1, '2025-08-01 09:44:53', '2025-08-01 09:45:13'),
(14, 'PO-000014', '', 1, '2025-08-09', '2025-08-09', 'received', 3900.00, 390.00, 4290.00, 0.00, 0.00, 'ddd', 1, '2025-08-09 08:59:49', '2025-08-09 09:01:52'),
(15, 'PO-000015', '', 1, '2025-08-09', '2025-08-09', 'draft', 689.68, 68.97, 758.65, 0.00, 0.00, NULL, 1, '2025-08-09 09:39:30', '2025-08-09 09:39:30'),
(16, 'PO-000016', '', 3, '2025-08-09', NULL, 'draft', 258.62, 25.86, 284.48, 0.00, 0.00, NULL, 1, '2025-08-09 09:41:14', '2025-08-09 09:41:14'),
(17, 'PO-000017', '', 1, '2025-08-09', NULL, 'draft', 258.62, 41.38, 300.00, 0.00, 0.00, NULL, 1, '2025-08-09 10:06:41', '2025-08-09 10:06:41'),
(18, 'PO-000018', 'INV-000018', 1, '2025-08-08', '0000-00-00', 'received', 517.24, 82.76, 600.00, 0.00, 0.00, '', 1, '2025-08-09 10:10:22', '2025-08-09 10:23:04'),
(19, 'PO-000019', 'INV-000019', 1, '2025-08-19', '2025-08-19', 'received', 172.41, 27.59, 200.00, 0.00, 0.00, NULL, 1, '2025-08-19 06:47:42', '2025-08-19 06:48:11');

-- --------------------------------------------------------

--
-- Table structure for table `purchase_order_items`
--

CREATE TABLE `purchase_order_items` (
  `id` int(11) NOT NULL,
  `purchase_order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `total_price` decimal(15,2) NOT NULL,
  `received_quantity` int(11) DEFAULT 0,
  `tax_amount` decimal(15,2) DEFAULT 0.00,
  `tax_type` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `purchase_order_items`
--

INSERT INTO `purchase_order_items` (`id`, `purchase_order_id`, `product_id`, `quantity`, `unit_price`, `total_price`, `received_quantity`, `tax_amount`, `tax_type`) VALUES
(1, 1, 10, 100, 400.00, 40000.00, 0, 0.00, NULL),
(3, 3, 1, 10, 800.00, 8000.00, 3, 0.00, NULL),
(4, 3, 2, 5, 15.00, 75.00, 4, 0.00, NULL),
(5, 4, 10, 1, 200.00, 200.00, 1, 0.00, NULL),
(7, 5, 7, 12, 309.99, 3719.88, 12, 0.00, NULL),
(8, 6, 10, 10, 200.00, 2000.00, 10, 0.00, NULL),
(9, 7, 6, 1, 4.00, 4.00, 1, 0.00, NULL),
(10, 8, 4, 2, 300.00, 600.00, 2, 0.00, NULL),
(11, 9, 6, 1, 299.98, 299.98, 1, 0.00, NULL),
(12, 10, 6, 10, 200.00, 2000.00, 10, 0.00, NULL),
(13, 2, 6, 1, 200.00, 200.00, 0, 0.00, NULL),
(14, 11, 7, 10, 300.00, 3000.00, 10, 0.00, NULL),
(15, 12, 5, 1, 200.00, 200.00, 1, 0.00, NULL),
(16, 13, 3, 100, 299.99, 29999.00, 0, 0.00, NULL),
(17, 13, 19, 1, 3.00, 3.00, 0, 0.00, NULL),
(19, 14, 34, 13, 300.00, 3900.00, 13, 0.00, NULL),
(20, 15, 21, 4, 172.42, 689.68, 0, 0.00, NULL),
(21, 16, 21, 1, 258.62, 258.62, 0, 0.00, NULL),
(22, 17, 27, 1, 258.62, 258.62, 0, 41.38, '16%'),
(24, 18, 26, 2, 300.00, 600.00, 1, 82.76, '16%'),
(25, 19, 18, 1, 200.00, 200.00, 1, 27.59, '16%');

-- --------------------------------------------------------

--
-- Table structure for table `receipts`
--

CREATE TABLE `receipts` (
  `id` int(11) NOT NULL,
  `receipt_number` varchar(20) NOT NULL,
  `client_id` int(11) NOT NULL,
  `invoice_number` int(50) NOT NULL,
  `sales_order_id` int(11) DEFAULT NULL,
  `receipt_date` date NOT NULL,
  `payment_method` enum('cash','check','bank_transfer','credit_card') NOT NULL,
  `reference_number` varchar(50) DEFAULT NULL,
  `amount` decimal(15,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` enum('draft','in pay','confirmed','cancelled') DEFAULT 'draft',
  `account_id` int(11) DEFAULT NULL,
  `reference` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `receipts`
--

INSERT INTO `receipts` (`id`, `receipt_number`, `client_id`, `invoice_number`, `sales_order_id`, `receipt_date`, `payment_method`, `reference_number`, `amount`, `notes`, `created_by`, `created_at`, `updated_at`, `status`, `account_id`, `reference`) VALUES
(1, 'RCP-2-1751828702405', 2, 0, NULL, '2025-07-06', 'cash', NULL, 700.70, '', 1, '2025-07-06 17:05:00', '2025-07-06 17:05:46', 'confirmed', 1, ''),
(2, 'RCP-1-1751997946596', 1, 0, NULL, '2025-07-08', 'cash', NULL, 60.50, '', 1, '2025-07-08 16:05:45', '2025-07-08 16:06:03', 'confirmed', 23, ''),
(3, 'RCP-3-1752319722476', 3, 0, NULL, '2025-07-12', 'cash', NULL, 8690.00, '', 1, '2025-07-12 09:28:41', '2025-07-12 09:29:10', 'confirmed', 22, ''),
(4, 'RCP-2-1752320067186', 2, 0, NULL, '2025-07-12', 'check', NULL, 400.00, '', 1, '2025-07-12 09:34:26', '2025-07-12 09:34:57', 'confirmed', 23, ''),
(5, 'RCP-2-1752320092374', 2, 0, NULL, '2025-07-12', 'cash', NULL, 300.00, '', 1, '2025-07-12 09:34:51', '2025-07-12 09:37:04', 'confirmed', 23, ''),
(6, 'RCP-2-1752320457182', 2, 0, NULL, '2025-07-12', 'check', NULL, 210.00, 'dd', 1, '2025-07-12 09:40:56', '2025-07-12 09:41:06', 'confirmed', 23, ''),
(7, 'RCP-2-1752322054452', 2, 0, NULL, '2025-07-12', 'check', NULL, 100.00, '', 1, '2025-07-12 10:07:33', '2025-07-12 10:07:40', 'confirmed', 23, ''),
(8, 'RCP-2-1752397788527', 2, 0, NULL, '2025-07-13', 'cash', NULL, 400.00, '', 1, '2025-07-13 07:09:45', '2025-07-13 07:09:59', 'confirmed', 21, ''),
(9, 'RCP-2-1752399439268', 2, 0, NULL, '2025-07-13', 'bank_transfer', NULL, 40.00, '', 1, '2025-07-13 07:37:16', '2025-07-13 07:59:58', 'confirmed', 23, 'testing'),
(10, 'RCP-2-1752400098114', 2, 0, NULL, '2025-07-13', 'bank_transfer', NULL, 200.00, '', 1, '2025-07-13 07:48:15', '2025-07-13 07:59:17', 'confirmed', 23, ''),
(11, 'RCP-2-1752401862705', 2, 0, NULL, '2025-07-13', 'bank_transfer', NULL, 30.50, '', 1, '2025-07-13 08:17:40', '2025-07-13 08:18:08', 'confirmed', 23, ''),
(12, 'RCP-2-1752402279902', 2, 0, NULL, '2025-07-13', 'bank_transfer', NULL, 35.00, '', 1, '2025-07-13 08:24:37', '2025-07-13 08:24:37', 'in pay', 23, ''),
(13, 'RCP-2-1752688371085', 2, 0, NULL, '2025-07-16', 'cash', NULL, 13200.00, '', 1, '2025-07-16 15:52:50', '2025-07-16 15:52:50', 'in pay', 22, ''),
(14, 'RCP-2-1752688371671', 2, 0, NULL, '2025-07-16', 'cash', NULL, 148.50, '', 1, '2025-07-16 15:52:51', '2025-07-16 15:52:51', 'in pay', 22, ''),
(15, 'RCP-2-1752688372253', 2, 0, NULL, '2025-07-16', 'cash', NULL, 99.00, '', 1, '2025-07-16 15:52:51', '2025-07-17 10:37:49', 'confirmed', 22, ''),
(16, 'RCP-2-1752757415185', 2, 0, NULL, '2025-07-17', 'cash', NULL, 93.50, '', 1, '2025-07-17 11:03:34', '2025-07-17 11:03:34', 'in pay', 23, ''),
(17, 'RCP-2-1752757416196', 2, 0, NULL, '2025-07-17', 'cash', NULL, 60.50, '', 1, '2025-07-17 11:03:35', '2025-07-17 11:03:35', 'in pay', 23, ''),
(18, 'RCP-10171-1754508671', 10171, 0, NULL, '2025-08-06', 'cash', NULL, 2000.00, 'test', 1, '2025-08-06 19:31:11', '2025-08-06 19:39:17', 'confirmed', 23, 'test'),
(19, 'RCP-10171-1754510399', 10171, 0, NULL, '2025-08-06', 'cash', NULL, 200.00, 'testing', 1, '2025-08-06 19:59:59', '2025-08-06 19:59:59', 'in pay', 21, 'testing'),
(20, 'RCP-10171-1754513126', 10171, 0, NULL, '2025-08-06', 'cash', NULL, 200.00, 'Payment for invoice 59', 1, '2025-08-06 20:45:26', '2025-08-06 20:45:26', 'in pay', 24, ''),
(22, 'RCP-10171-1754513370', 10171, 59, NULL, '2025-08-06', 'cash', NULL, 4.00, 'f', 1, '2025-08-06 20:49:30', '2025-08-06 20:50:55', 'confirmed', 23, 'f'),
(23, 'RCP-2430-17547707338', 2430, 70, NULL, '2025-08-09', 'cash', NULL, 1200.00, '', 1, '2025-08-09 20:18:53', '2025-08-09 20:18:53', 'in pay', 23, ''),
(24, 'RCP-2221-17555766320', 2221, 73, NULL, '2025-08-19', 'cash', NULL, 2000.00, 'test', 1, '2025-08-19 04:10:30', '2025-08-19 04:12:07', 'confirmed', 23, 'test');

-- --------------------------------------------------------

--
-- Table structure for table `Regions`
--

CREATE TABLE `Regions` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `countryId` int(11) NOT NULL,
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Regions`
--

INSERT INTO `Regions` (`id`, `name`, `countryId`, `status`) VALUES
(1, 'NAIROBI', 1, 0),
(3, 'ELDORET', 1, 0),
(7, 'NAIROBI NORTH\n', 1, 0),
(8, 'NAIROBI SOUTH\n', 1, 0),
(9, 'KISUMU', 1, 0),
(10, 'MOMBASA', 1, 0),
(11, 'MOUNTAIN', 1, 0),
(12, 'NAKURU', 1, 0),
(13, 'SOTIK', 2, 0),
(14, 'Arusha', 2, 0),
(15, 'Mwanza', 2, 0),
(16, 'Dodoma', 2, 0),
(17, 'Tanga', 2, 0),
(18, 'Mbeya', 2, 0),
(19, 'Morogoro', 2, 0),
(20, 'Iringa', 2, 0);

-- --------------------------------------------------------

--
-- Table structure for table `retail_targets`
--

CREATE TABLE `retail_targets` (
  `id` int(11) NOT NULL,
  `sales_rep_id` int(11) NOT NULL,
  `vapes_targets` int(11) DEFAULT 0,
  `pouches_targets` int(11) DEFAULT 0,
  `new_outlets_targets` int(11) DEFAULT 0,
  `target_month` varchar(7) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `start_date` date NOT NULL,
  `end_date` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `retail_targets`
--

INSERT INTO `retail_targets` (`id`, `sales_rep_id`, `vapes_targets`, `pouches_targets`, `new_outlets_targets`, `target_month`, `created_at`, `start_date`, `end_date`) VALUES
(1, 4, 10, 2, 0, '2025-07', '2025-07-18 08:10:14', '2025-07-01', '2025-07-31'),
(2, 94, 163, 20, 0, '2025-07', '2025-07-22 18:38:00', '2025-07-01', '2025-07-31');

-- --------------------------------------------------------

--
-- Table structure for table `Riders`
--

CREATE TABLE `Riders` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `contact` varchar(191) NOT NULL,
  `id_number` varchar(191) NOT NULL,
  `company_id` int(11) NOT NULL,
  `company` varchar(191) NOT NULL,
  `status` int(11) DEFAULT NULL,
  `password` varchar(191) DEFAULT NULL,
  `device_id` varchar(191) DEFAULT NULL,
  `device_name` varchar(191) DEFAULT NULL,
  `device_status` varchar(191) DEFAULT NULL,
  `token` varchar(191) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Riders`
--

INSERT INTO `Riders` (`id`, `name`, `contact`, `id_number`, `company_id`, `company`, `status`, `password`, `device_id`, `device_name`, `device_status`, `token`) VALUES
(1, 'Bryan Otieno', '0790193625', '33', 1, 'Company A', NULL, 'd8578edf8458ce06fbc5bb76a58c5ca4', '04a2bf595de3ad29', 'samsung SM-A127F', NULL, 'fXUYZp5UPrE:APA91bEgy-uM7Lhy1ooFg_nceJ8GM5-YhLw1zBDKjfuOUsZqGj2q6sufOyjUQcGDPdrZ7V9rmeQqwZjHykn0nKpTY7gBkMEsUmX_ibDBEPWtvfZbkst_Fcg'),
(2, 'Rider 1', '123', '123', 1, 'Company', NULL, 'd8578edf8458ce06fbc5bb76a58c5ca4', NULL, NULL, NULL, NULL),
(3, 'Test Rider', '1234567890', 'ID123456', 1, 'Test Company', 1, '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', NULL, NULL, NULL, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjMsIm5hbWUiOiJUZXN0IFJpZGVyIiwiY29udGFjdCI6IjEyMzQ1Njc4OTAiLCJ0eXBlIjoicmlkZXIiLCJpYXQiOjE3NTYxMzkwMjUsImV4cCI6MTc1NjE0MjYyNX0.wwEU_tQg2fJdHIya7l');

-- --------------------------------------------------------

--
-- Table structure for table `riders_company`
--

CREATE TABLE `riders_company` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `status` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `riders_company`
--

INSERT INTO `riders_company` (`id`, `name`, `status`) VALUES
(1, 'Moonsun Internal', 1),
(2, 'Quick Zingo', 1);

-- --------------------------------------------------------

--
-- Table structure for table `routes`
--

CREATE TABLE `routes` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `region` int(11) NOT NULL,
  `region_name` varchar(100) NOT NULL,
  `country_id` int(11) NOT NULL,
  `country_name` varchar(100) NOT NULL,
  `leader_id` int(11) NOT NULL,
  `leader_name` varchar(100) NOT NULL,
  `status` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `routes`
--

INSERT INTO `routes` (`id`, `name`, `region`, `region_name`, `country_id`, `country_name`, `leader_id`, `leader_name`, `status`) VALUES
(1, 'NAIROBI WEST', 1, 'Nairobi', 1, 'Kenya', 1, 'Benjamin', 0),
(2, 'NAIROBI EAST\n', 1, 'Nairobi', 1, 'Kenya', 1, 'Benjamin', 0),
(3, 'NAIROBI NORTH\n', 1, 'Nairobi', 1, '', 0, '', 0),
(4, 'NAIROBI SOUTH\n', 1, '', 1, '', 0, '', 0),
(5, 'ELDORET', 1, '', 1, '', 0, '', 0),
(6, 'KISUMU', 1, '', 1, '', 0, '', 0),
(7, 'MOMBASA', 1, '', 1, '', 0, '', 0),
(8, 'MOUNTAIN', 1, '', 1, '', 0, '', 0),
(9, 'NAKURU', 1, '', 1, '', 0, '', 0),
(10, 'WESTERN& NYANZA\n', 1, '', 1, '', 0, '', 0),
(11, 'LANGATA RD/KAREN/RONGAI/NGONG/MSA RD', 1, '', 1, '', 0, '', 0),
(55, 'KAKAMEGA/BUNGOMA/KISUMU', 1, '', 1, '', 0, '', 0),
(56, 'Nairobi Central', 0, '', 0, '', 0, '', 0),
(57, 'Mombasa Coast', 0, '', 0, '', 0, '', 0),
(58, 'Dar Central', 0, '', 0, '', 0, '', 0),
(59, 'Arusha North', 0, '', 0, '', 0, '', 0),
(60, 'Kisumu West', 0, '', 0, '', 0, '', 0),
(61, 'Nakuru East', 0, '', 0, '', 0, '', 0),
(62, 'Eldoret North', 0, '', 0, '', 0, '', 0),
(63, 'Mwanza Central', 0, '', 0, '', 0, '', 0),
(64, 'Dodoma Central', 0, '', 0, '', 0, '', 0),
(65, 'Tanga Coast', 0, '', 0, '', 0, '', 0),
(66, 'Thika Industrial', 0, '', 0, '', 0, '', 0),
(67, 'Machakos East', 0, '', 0, '', 0, '', 0),
(68, 'Kakamega West', 0, '', 0, '', 0, '', 0),
(69, 'Mbeya Highlands', 0, '', 0, '', 0, '', 0),
(70, 'Morogoro Central', 0, '', 0, '', 0, '', 0),
(71, 'Iringa South', 0, '', 0, '', 0, '', 0);

-- --------------------------------------------------------

--
-- Table structure for table `salesclient_payment`
--

CREATE TABLE `salesclient_payment` (
  `id` int(11) NOT NULL,
  `clientId` int(11) NOT NULL,
  `amount` double NOT NULL,
  `invoicefileUrl` varchar(191) DEFAULT NULL,
  `date` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `status` varchar(191) DEFAULT NULL,
  `payment_method` varchar(191) DEFAULT NULL,
  `salesrepId` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `salesclient_payment`
--

INSERT INTO `salesclient_payment` (`id`, `clientId`, `amount`, `invoicefileUrl`, `date`, `status`, `payment_method`, `salesrepId`) VALUES
(1, 1796, 200, 'https://res.cloudinary.com/otienobryan/image/upload/v1754221137/whoosh/payments/sdpfdcmgygjppowtky0s.jpg', '2025-08-03 11:38:57.714', 'PENDING', 'Cash', 94),
(2, 1796, 100000, 'https://res.cloudinary.com/otienobryan/image/upload/v1754221521/whoosh/payments/oihkzr01vgfdx6ahfzbo.jpg', '2025-08-03 11:45:21.597', 'PENDING', 'Bank', 94),
(3, 10205, 20, 'https://res.cloudinary.com/otienobryan/image/upload/v1754229894/whoosh/payments/zcplywfvzh2mhqp2zic1.jpg', '2025-08-03 14:04:54.628', 'PENDING', 'Bank', 94);

-- --------------------------------------------------------

--
-- Table structure for table `SalesRep`
--

CREATE TABLE `SalesRep` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `email` varchar(191) NOT NULL,
  `phoneNumber` varchar(191) NOT NULL,
  `password` varchar(191) NOT NULL,
  `countryId` int(11) NOT NULL,
  `country` varchar(191) NOT NULL,
  `region_id` int(11) NOT NULL,
  `region` varchar(191) NOT NULL,
  `route_id` int(11) NOT NULL,
  `route` varchar(100) NOT NULL,
  `route_id_update` int(11) NOT NULL,
  `route_name_update` varchar(100) NOT NULL,
  `visits_targets` int(3) NOT NULL,
  `new_clients` int(3) NOT NULL,
  `vapes_targets` int(11) NOT NULL,
  `pouches_targets` int(11) NOT NULL,
  `role` varchar(191) DEFAULT 'USER',
  `manager_type` int(11) NOT NULL,
  `status` int(11) DEFAULT 0,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `updatedAt` datetime(3) NOT NULL,
  `retail_manager` int(11) NOT NULL,
  `key_channel_manager` int(11) NOT NULL,
  `distribution_manager` int(11) NOT NULL,
  `photoUrl` varchar(191) DEFAULT '',
  `managerId` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `SalesRep`
--

INSERT INTO `SalesRep` (`id`, `name`, `email`, `phoneNumber`, `password`, `countryId`, `country`, `region_id`, `region`, `route_id`, `route`, `route_id_update`, `route_name_update`, `visits_targets`, `new_clients`, `vapes_targets`, `pouches_targets`, `role`, `manager_type`, `status`, `createdAt`, `updatedAt`, `retail_manager`, `key_channel_manager`, `distribution_manager`, `photoUrl`, `managerId`) VALUES
(94, 'Benjamin Okwamas Test', 'bennjiokwama@gmail.com', '0706166875', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'Kenya', 1, 'Kenya', 1, 'NAIVASHA/NYANDARUA/GILGIL/NYAHURURU', 7, 2, 20, 20, 'SALES_REP', 0, 1, '2025-06-03 14:51:56.089', '2025-07-13 13:40:59.000', 2, 0, 9, 'https://res.cloudinary.com/otienobryan/image/upload/v1754063915/whoosh/profile_photos/profile_94_1754063910175.png', NULL),
(129, 'BRYAN OTIENO ONYANGO', 'bryanotieno0ss9@gmail.com', '0790193625', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'Nairobi', 1, '', 1, 'LANGATA RD/KAREN/RONGAI/NGONG/MSA RD', 0, 0, 0, 0, 'USER', 0, 1, '2025-08-27 07:45:40.887', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(130, 'Sharon Irungu ', 'sharon@gmail.com', '071456481', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:13:56.210', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(131, 'Naomi Gateri', 'naomi@gmail.com', '0714432767', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:14:37.693', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(132, ' Christine Ngonyo ', 'christine@gmail.com', '0713107260', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:15:13.146', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(133, 'Dennis Munene ', 'christine@gmail.com', '0718187634', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:15:44.602', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(134, ' Ferdinard Omondi Owino ', 'christine@gmail.com', '0799515944', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:16:09.926', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(135, ' Amos Langat ', 'christine@gmail.com', '0721344804', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:16:34.798', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(136, 'Movin Omole', 'movin@gmail.com', '0759617685', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:17:10.740', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(137, 'Joyce Anono', 'joyce@gmail.com', '0715129887', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:17:41.709', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(138, 'Xavier Otieno ', 'xavier@gmail.com', '0705697994', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:18:15.514', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(139, 'Benard Ndungu', 'benard@gmail.com', '0748448033', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:18:56.891', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(140, 'Rachael Wangeci', 'rachael@gmail.com', '0719827512', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:19:29.444', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(141, 'Vincent Momanyi (Direct)', 'vincent@gmail.com', '0719446785', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:20:04.752', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(142, 'Fedelis Mumo', 'fedelis@gmail.com', '0725542935', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:20:40.350', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(143, 'George Kennedy ', 'george@gmail.com', '0727964989', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:21:05.319', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(144, 'Ann Sandra Soko ', 'soko@gmail.com', '0729706056', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:21:33.657', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(145, ' Danline Adhiambo ', 'danline@gmail.com', '0757612803', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:22:11.897', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(146, 'Teresia Wamae (Direct)', 'teresial@gmail.com', '0726884760', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:22:38.827', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(147, ' Mercy Mwathe ', 'mercy@gmail.com', '0745283487', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:23:20.276', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(149, ' Ann Akoth  ', 'ann@gmail.com', '0723058447', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:26:32.778', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(150, ' Damaris Wamaitha  ', 'dama@gmail.com', '0112198124', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:28:08.705', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(151, ' Justin Nakami  ', 'justin@gmail.com', '0723920538', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:28:32.324', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(152, ' Bikky Awuor ', 'justin@gmail.com', '0728685694', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:28:56.574', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(153, ' Betty Ambogo Mege ', 'betty@gmail.com', '0721624426', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:30:41.338', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(154, ' kate Winsley ', 'betty@gmail.com', '0717244273', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:31:05.223', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(155, ' Faith Otieno  ', 'betty@gmail.com', '0798462923', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:31:23.619', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(156, ' Jesse Otsyeno ', 'betty@gmail.com', '0705159154', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:32:13.257', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(157, ' Sharon kitumbi  ', 'betty@gmail.com', '0740835648', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:33:34.876', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(158, ' Grace Wangare(Direct) ', 'betty@gmail.com', '0726872309', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:34:07.260', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(159, ' Giesel Codawa  ', 'giesel@gmail.com', '0700192902', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:34:34.404', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(160, 'Annastacia Makau', 'makau@gmail.com', '0746148284', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:35:02.261', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(161, 'Ann Njoki', 'ann1@gmail.com', '0742600339', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:35:27.021', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(162, 'Brain Kiilu', 'ann1@gmail.com', '0798104988', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:35:49.724', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(163, 'Linda Pudo', 'linda@gmail.com', '0722146604', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI EAST\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:36:14.580', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(164, ' Norah Gathii  ', 'norah@gmail.com', '0722146604', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:36:42.865', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(165, ' Elphas Okocha  ', 'okocha@gmail.com', '0729428020', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:37:19.713', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(166, ' Elphas Okocha  ', 'okocha@gmail.com', '0729428020', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:38:49.972', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(167, ' Bonface  Atyang ', 'bonface@gmail.com', '0796038674', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:39:36.181', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(168, ' Eric Munene ', 'eric@gmail.com', '0719827512', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:40:42.447', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(169, ' Alice Anyango  ', 'alice@gmail.com', '0707060824', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:41:07.601', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(170, ' Lilian Aoko ', 'aoko@gmail.com', '0721783841', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:41:37.389', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(171, ' Breen Andati  ', 'breen@gmail.com', '0798373046', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:41:59.928', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(172, ' Beth Gathii ', 'beth@gmail.com', '0727357663', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:42:22.706', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(173, ' Grace Wangare(Direct) ', 'grace@gmail.com', '0726872309', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:42:47.454', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(174, ' Irene Akoth ', 'irene@gmail.com', '0799421906', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:43:11.533', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(175, ' Janet Gatwiri  ', 'janet@gmail.com', '0798688832', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:43:37.992', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(176, ' David murithi ', 'david@gmail.com', '0718268558', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:44:14.906', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(177, ' Mary Njeri  ', 'mary@gmail.com', '0743340522', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:44:38.802', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(178, ' Joan Akoth ', 'joan@gmail.com', '0713596265', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:45:18.153', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(179, 'Fredrik Murioki (Direct)', 'fred@gmail.com', '0725970381', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:45:44.830', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(180, 'Dorcus Kathini', 'dorcus@gmail.com', '0759721860', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:46:12.293', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(181, ' Lilian Mweni ', 'mueni@gmail.com', '0720098443', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:46:52.380', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(182, ' Gaddafi Okoth ', 'okoth@gmail.com', '0711535863', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:48:48.520', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(183, ' Clare Cherotich(Direct)  ', 'clare@gmail.com', '0703357915', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:49:14.569', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(184, 'Catherine Kwamboka ', 'catherie@gmail.com', '0720079706', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:49:36.301', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(185, ' Jecinta Ayande ', 'jacinta@gmail.com', '0729255197', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:50:05.977', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(186, ' Christine Wambui ', 'wambui@gmail.com', '0729915584', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:50:38.696', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(187, ' Victor Owino ', 'owino@gmail.com', '0713219941', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:51:08.802', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(188, ' Rita Atieno ', 'rita@gmail.com', '0791041966', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:51:33.861', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(189, ' Esther Mumbi(Direct) ', 'eshter@gmail.com', '0726950009', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:51:56.498', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(190, ' Prudent Mwende ', 'prudent@gmail.com', '0714175885', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:52:17.829', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(191, ' Faith Murigi ', 'murigi@gmail.com', '0725970130', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:52:58.989', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(192, ' Ida Muteti ', 'ida@gmail.com', '0719760480', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI SOUTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 15:53:19.879', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(194, 'Kisia William', 'kisia@gmail.com', '0708242670', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:00:28.122', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(195, 'Jennifer Jepkoech ', 'jennifer@gmail.com', '0717673901', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:00:59.846', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(196, 'Abigael Jebet ', 'abi@gmail.com', '0720091907', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:01:28.060', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(197, 'Centrine Nasike ', 'abi@gmail.com', '0791571050', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:02:02.338', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(198, 'Kiprotich Enock Sang', 'abi@gmail.com', '0706335953', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:02:30.820', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(199, 'Irene Chebet ', 'abi@gmail.com', '0725577971', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'ELDORET', 1, '', 0, 'ELDORET', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:02:56.588', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(200, 'Libra Katta', 'user@gmail.com', '0740560264', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:04:41.651', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(201, 'Shadrack Khisa', 'user@gmail.com', '0745020387', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:05:09.916', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(202, 'Valaria Sebi', 'user@gmail.com', '0792075417', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:05:29.752', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(203, 'Dennis Wangila', 'user@gmail.com', '0700194896', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:05:47.668', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(204, 'Alvin Onyango', 'user@gmail.com', '0792103680', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:06:06.735', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(205, 'Brian Otieno', 'user@gmail.com', '0715669612', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'KISUMU', 1, '', 0, 'KISUMU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:06:25.785', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(206, 'Evelyn  Were', 'user@gmail.com', '0724532225', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:07:48.037', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(207, 'Naomi Sidi Nzai', 'user@gmail.com', '0712945620', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:08:08.099', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(208, 'Ruth Betty Kyalya', 'user@gmail.com', '0713666878', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:08:28.860', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(209, 'Molly Adhiambo', 'user@gmail.com', '0748228950', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:08:47.392', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(210, 'Fatma Ally Ramadhan ', 'user@gmail.com', '0792757341', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:09:06.842', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(211, 'Purity mbete Philip ', 'user@gmail.com', '0717966520', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:09:32.598', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(212, 'Ruth Kanini', 'user@gmail.com', '0745795027', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOMBASA', 1, '', 0, 'MOMBASA', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:09:56.706', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(213, 'CIRIAK NJERU ', 'user@gmail.com', '0711679489', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:11:06.678', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(214, 'CLARE OMONDI ', 'user@gmail.com', '0719414224', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:11:26.151', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(215, 'MILLICENT NJUGI ', 'user@gmail.com', '0704433032', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:11:47.237', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(216, 'VALENTINE MUTHONI ', 'user@gmail.com', '0716878521', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:12:12.914', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(217, 'KELVIN NYAKWAMA ', 'user@gmail.com', '0743268997', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:12:35.766', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(218, 'Cynthia Wanja', 'user@gmail.com', '0707008721', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:12:57.509', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(219, 'Emma Wangui', 'user@gmail.com', '0793378162', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:13:21.290', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(220, 'Magreat Wanjiru', 'user@gmail.com', '0724937656', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'MOUNTAIN', 1, '', 0, 'MOUNTAIN', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:13:44.059', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(221, 'GIDEON KIPKORIR', 'user@gmail.com', '0705850021', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:15:11.432', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(222, 'BRIAN KIPTOO', 'user@gmail.com', '0705409779', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:15:32.012', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(223, 'ABIGAEL YATOR', 'user@gmail.com', '0704411965', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:15:53.128', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(224, 'JUDY MUTHONI NGUGI', 'user@gmail.com', '0796069555', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:16:12.741', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(225, 'MARY NDINGA MUTUA', 'user@gmail.com', '0748092884', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:16:33.664', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(226, 'PURITY KAARI ', 'user@gmail.com', '07000', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAKURU', 1, '', 0, 'NAKURU', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:16:54.997', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(227, 'Gladys Cherono', 'user@gmail.com', '0707144693', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:19:58.452', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(228, 'Edwin Kadeso', 'user@gmail.com', '0794304913', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:20:21.818', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(229, 'Nyabuto Nyaboke Daisy ', 'user@gmail.com', '07111', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:20:54.492', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(230, 'Bill Clinton', 'user@gmail.com', '0708199465', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:21:13.269', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(231, 'Yvone  Atieno', 'user@gmail.com', '0758792474', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:21:31.900', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(232, 'Joan Odero', 'user@gmail.com', '0719523968', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:21:53.567', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(233, 'Faith Chemutai', 'user@gmail.com', '0719523968', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'SOTIK', 1, '', 0, 'WESTERN& NYANZA\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 16:22:23.267', '2025-07-13 13:40:59.000', 0, 0, 0, NULL, NULL),
(234, 'Lilian Anyango', 'user@gmail.com', '0728302994', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI NORTH\n', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 20:50:19.563', '0000-00-00 00:00:00.000', 0, 0, 0, NULL, NULL),
(235, 'Royd Karani', 'user@gmail.com', '0729601846', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 1, 'Kenya', 1, 'NAIROBI', 1, '', 0, 'NAIROBI WEST', 0, 0, 0, 0, 'USER', 0, 1, '2025-09-02 20:54:31.315', '0000-00-00 00:00:00.000', 0, 0, 0, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `sales_orders`
--

CREATE TABLE `sales_orders` (
  `id` int(11) NOT NULL,
  `so_number` varchar(20) NOT NULL,
  `client_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `expected_delivery_date` date DEFAULT NULL,
  `subtotal` decimal(15,2) DEFAULT 0.00,
  `tax_amount` decimal(15,2) DEFAULT 0.00,
  `total_amount` decimal(15,2) DEFAULT 0.00,
  `net_price` decimal(11,2) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `salesrep` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `rider_id` int(11) DEFAULT NULL,
  `assigned_at` timestamp NULL DEFAULT '0000-00-00 00:00:00',
  `recepients_name` varchar(255) DEFAULT NULL,
  `recepients_contact` varchar(255) DEFAULT NULL,
  `dispatched_by` int(11) DEFAULT NULL,
  `status` enum('draft','confirmed','shipped','delivered','cancelled','in payment','paid') DEFAULT 'draft',
  `my_status` tinyint(3) NOT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `received_by` int(11) NOT NULL,
  `delivery_image` varchar(500) DEFAULT NULL COMMENT 'Path/URL of the delivery photo captured by rider',
  `returned_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `sales_orders`
--

INSERT INTO `sales_orders` (`id`, `so_number`, `client_id`, `order_date`, `expected_delivery_date`, `subtotal`, `tax_amount`, `total_amount`, `net_price`, `notes`, `created_by`, `salesrep`, `created_at`, `updated_at`, `rider_id`, `assigned_at`, `recepients_name`, `recepients_contact`, `dispatched_by`, `status`, `my_status`, `delivered_at`, `received_by`, `delivery_image`, `returned_at`) VALUES
(55, 'INV-55', 168, '2025-08-04', NULL, 10000.00, 1000.00, 11000.00, 11600.00, NULL, NULL, 94, '2025-08-04 21:02:40', '2025-08-06 10:05:34', 1, '2025-08-06 11:05:36', NULL, NULL, 1, 'confirmed', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(56, 'INV-56', 1796, '2025-08-06', NULL, 6000.00, 600.00, 6600.00, 6960.00, NULL, NULL, 94, '2025-08-06 10:33:49', '2025-08-06 12:26:35', 1, '2025-08-06 13:26:38', NULL, NULL, 1, 'confirmed', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(57, 'INV-57', 10171, '2025-08-06', NULL, 2000.00, 200.00, 2200.00, 2320.00, NULL, NULL, 94, '2025-08-06 14:50:24', '2025-08-25 12:28:39', 3, '2025-08-25 10:28:40', NULL, NULL, 1, 'delivered', 2, '2025-08-25 08:30:40', 0, NULL, '0000-00-00 00:00:00'),
(58, 'INV-58', 10171, '2025-08-06', NULL, 4000.00, 400.00, 4400.00, 4640.00, NULL, NULL, 94, '2025-08-06 18:44:45', '2025-08-06 18:46:21', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(60, 'INV-60', 10171, '2025-08-07', NULL, 2000.00, 200.00, 2200.00, 2320.00, NULL, NULL, 94, '2025-08-07 01:08:36', '2025-08-07 03:09:12', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(61, 'INV-61', 10171, '2025-08-07', NULL, 4000.00, 400.00, 4400.00, 4640.00, NULL, NULL, 94, '2025-08-07 03:09:57', '2025-08-07 03:10:10', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(63, 'SO-2025-0002', 10171, '2025-08-06', NULL, 5172.41, 827.59, 6000.00, 6960.00, '', NULL, 94, '2025-08-08 03:02:42', '2025-08-25 12:47:15', 3, '0000-00-00 00:00:00', NULL, NULL, NULL, 'draft', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(64, 'INV-64', 10171, '2025-08-05', NULL, 5172.41, 827.59, 6000.00, 6960.00, '', NULL, 94, '2025-08-08 03:17:56', '2025-08-10 11:54:21', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(65, 'INV-65', 1796, '2025-08-06', NULL, 1724.14, 275.86, 2000.00, 2000.00, 'new irder', NULL, 94, '2025-08-08 03:32:47', '2025-08-08 03:55:59', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(66, 'SO-2025-0004', 10233, '2025-08-04', NULL, 3448.28, 551.72, 4000.00, 4000.00, ' | Products returned to stock on 2025-08-11 14:43:31 | Products returned to stock on 2025-08-11 14:48:38 | Products returned to stock on 2025-08-11 15:09:39', NULL, 94, '2025-08-08 12:30:20', '2025-08-11 13:09:39', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'cancelled', 6, NULL, 1, NULL, '2025-08-11 15:09:39'),
(70, 'INV-70', 2221, '2025-08-09', NULL, 6000.00, 0.00, 6000.00, 6000.00, NULL, NULL, 94, '2025-08-09 16:50:03', '2025-08-10 21:28:06', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(71, 'INV-71', 2221, '2025-08-12', NULL, 2000.00, 0.00, 2000.00, 2000.00, NULL, NULL, 94, '2025-08-12 08:39:01', '2025-08-12 08:40:02', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(72, 'INV-72', 2221, '2025-08-12', NULL, 1724.14, 275.86, 2000.00, 0.00, NULL, 1, NULL, '2025-08-12 08:42:43', '2025-08-12 08:43:09', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(73, 'INV-73', 2221, '2025-08-19', NULL, 2000.00, 0.00, 2000.00, 2000.00, NULL, NULL, 94, '2025-08-19 03:42:49', '2025-08-19 04:28:21', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(74, 'INV-74', 389, '2025-08-19', '2025-08-19', 334.42, 53.51, 387.93, 0.00, NULL, 1, NULL, '2025-08-19 06:46:43', '2025-08-19 06:47:30', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(75, 'INV-75', 389, '2025-08-19', '2025-08-19', 387.93, 62.07, 450.00, 0.00, NULL, 1, NULL, '2025-08-19 06:53:22', '2025-08-19 06:54:37', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(76, 'INV-76', 2263, '2025-08-19', NULL, 3800.00, 0.00, 3800.00, 3800.00, 'Payment on delivery, include a display', NULL, 2, '2025-08-19 09:40:18', '2025-08-19 09:45:12', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(77, 'INV-77', 389, '2025-08-19', NULL, 334.42, 53.51, 387.93, 0.00, NULL, 1, NULL, '2025-08-19 09:52:59', '2025-08-19 09:53:44', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'confirmed', 1, NULL, 0, NULL, '0000-00-00 00:00:00'),
(78, 'INV-78', 389, '2025-08-19', NULL, 387.93, 62.07, 450.00, 0.00, NULL, 1, NULL, '2025-08-19 09:54:49', '2025-08-25 12:42:16', 1, '2025-08-25 10:42:17', NULL, NULL, 1, 'confirmed', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(79, 'SO-000020', 2430, '2025-08-22', '2025-08-22', 0.00, 0.00, 2000.00, 0.00, NULL, 1, NULL, '2025-08-22 11:44:16', '2025-08-22 11:44:16', NULL, '0000-00-00 00:00:00', NULL, NULL, NULL, 'draft', 0, NULL, 0, NULL, '0000-00-00 00:00:00'),
(94, 'SO-002031', 2430, '2025-08-22', NULL, 200.00, 32.00, 232.00, 0.00, NULL, 1, NULL, '2025-08-22 14:13:29', '2025-08-25 12:47:19', 3, '0000-00-00 00:00:00', NULL, NULL, NULL, 'draft', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(95, 'INV-95', 2430, '2025-08-22', NULL, 2000.00, 320.00, 2320.00, 0.00, NULL, 1, NULL, '2025-08-22 14:14:40', '2025-08-22 14:19:41', 1, '2025-08-22 14:19:41', NULL, NULL, 1, 'confirmed', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(97, 'INV-97', 267, '2025-08-25', NULL, 10800.00, 0.00, 10800.00, 10800.00, 'Payment on delivery', NULL, 2, '2025-08-25 11:57:41', '2025-08-25 12:41:07', 1, '2025-08-25 10:41:08', NULL, NULL, 1, 'confirmed', 2, NULL, 0, NULL, '0000-00-00 00:00:00'),
(98, 'INV-98', 1796, '2025-08-25', NULL, 1100.00, 0.00, 1100.00, 1100.00, 'test', NULL, 94, '2025-08-25 12:43:44', '2025-08-25 12:50:49', 3, '2025-08-25 10:50:48', NULL, NULL, 1, 'shipped', 2, NULL, 0, NULL, '0000-00-00 00:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `sales_order_items`
--

CREATE TABLE `sales_order_items` (
  `id` int(11) NOT NULL,
  `sales_order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `tax_amount` decimal(11,2) NOT NULL,
  `total_price` decimal(15,2) NOT NULL,
  `tax_type` enum('16%','zero_rated','exempted') DEFAULT '16%',
  `net_price` decimal(11,2) NOT NULL,
  `shipped_quantity` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `sales_order_items`
--

INSERT INTO `sales_order_items` (`id`, `sales_order_id`, `product_id`, `quantity`, `unit_price`, `tax_amount`, `total_price`, `tax_type`, `net_price`, `shipped_quantity`) VALUES
(49, 43, 6, 1, 2000.00, 0.00, 2000.00, '16%', 0.00, 0),
(54, 44, 6, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(55, 42, 6, 5, 2000.00, 0.00, 10000.00, '16%', 0.00, 0),
(57, 46, 7, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(58, 47, 7, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(59, 48, 13, 1, 2000.00, 320.00, 2320.00, '16%', 2000.00, 0),
(60, 45, 7, 1, 2000.00, 0.00, 2000.00, '16%', 0.00, 0),
(61, 49, 10, 1, 3000.00, 480.00, 3480.00, '16%', 3000.00, 0),
(62, 50, 21, 1, 200.00, 32.00, 232.00, '16%', 200.00, 0),
(63, 54, 6, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(65, 55, 7, 5, 2000.00, 1600.00, 10000.00, '', 11600.00, 0),
(68, 56, 7, 3, 2000.00, 960.00, 6000.00, '', 6960.00, 0),
(69, 57, 7, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(70, 58, 7, 2, 2000.00, 640.00, 4000.00, '', 4640.00, 0),
(71, 59, 7, 3, 2000.00, 960.00, 6000.00, '', 6960.00, 0),
(72, 60, 7, 1, 2000.00, 320.00, 2000.00, '', 2320.00, 0),
(73, 61, 7, 2, 2000.00, 640.00, 4000.00, '', 4640.00, 0),
(76, 62, 7, 4, 2000.00, 0.00, 8000.00, '16%', 0.00, 0),
(80, 63, 7, 3, 2000.00, 827.59, 6000.00, '16%', 5172.41, 0),
(84, 64, 7, 3, 2000.00, 827.59, 6000.00, '16%', 6000.00, 0),
(85, 65, 7, 1, 2000.00, 275.86, 2000.00, '16%', 2000.00, 0),
(101, 69, 7, 2, 2000.00, 551.72, 4000.00, '16%', 4000.00, 0),
(102, 66, 7, 2, 2000.00, 551.72, 4000.00, '16%', 4000.00, 0),
(103, 70, 7, 3, 2000.00, 827.59, 6000.00, '', 6000.00, 0),
(104, 71, 7, 1, 2000.00, 275.86, 2000.00, '', 2000.00, 0),
(105, 72, 40, 1, 2000.00, 275.86, 2000.00, '16%', 2000.00, 0),
(106, 73, 7, 1, 2000.00, 275.86, 2000.00, '', 2000.00, 0),
(107, 74, 21, 1, 387.93, 53.51, 387.93, '16%', 387.93, 0),
(108, 75, 26, 1, 450.00, 62.07, 450.00, '16%', 450.00, 0),
(109, 76, 6, 1, 2000.00, 275.86, 2000.00, '', 2000.00, 0),
(110, 76, 43, 1, 1800.00, 248.28, 1800.00, '', 1800.00, 0),
(111, 77, 26, 1, 387.93, 53.51, 387.93, '16%', 387.93, 0),
(112, 78, 27, 1, 450.00, 62.07, 450.00, '16%', 450.00, 0),
(113, 79, 22, 1, 2000.00, 275.86, 2000.00, '16%', 2000.00, 0),
(124, 94, 5, 1, 200.00, 32.00, 232.00, '16%', 232.00, 0),
(125, 95, 5, 1, 2000.00, 320.00, 2320.00, '16%', 2320.00, 0),
(130, 96, 22, 12, 400.00, 662.07, 4800.00, '', 4800.00, 0),
(131, 96, 21, 12, 400.00, 662.07, 4800.00, '', 4800.00, 0),
(132, 97, 22, 12, 450.00, 744.83, 5400.00, '', 5400.00, 0),
(133, 97, 21, 12, 450.00, 744.83, 5400.00, '', 5400.00, 0),
(134, 98, 7, 1, 1100.00, 151.72, 1100.00, '', 1100.00, 0);

-- --------------------------------------------------------

--
-- Table structure for table `sales_rep_managers`
--

CREATE TABLE `sales_rep_managers` (
  `id` int(11) NOT NULL,
  `sales_rep_id` int(11) NOT NULL,
  `manager_id` int(11) NOT NULL,
  `manager_type` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `sales_rep_managers`
--

INSERT INTO `sales_rep_managers` (`id`, `sales_rep_id`, `manager_id`, `manager_type`) VALUES
(3, 4, 1, 'Retail'),
(4, 4, 9, 'Distribution'),
(5, 94, 10, 'Retail'),
(6, 94, 1, 'Distribution'),
(7, 94, 9, 'Key Account');

-- --------------------------------------------------------

--
-- Table structure for table `sales_rep_manager_assignments`
--

CREATE TABLE `sales_rep_manager_assignments` (
  `id` int(11) NOT NULL,
  `sales_rep_id` int(11) NOT NULL,
  `manager_id` int(11) NOT NULL,
  `manager_type` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `sales_rep_manager_assignments`
--

INSERT INTO `sales_rep_manager_assignments` (`id`, `sales_rep_id`, `manager_id`, `manager_type`) VALUES
(1, 4, 1, 'Retail'),
(2, 4, 10, 'Key Account'),
(3, 4, 9, 'Distribution');

-- --------------------------------------------------------

--
-- Table structure for table `ShowOfShelfReport`
--

CREATE TABLE `ShowOfShelfReport` (
  `id` int(11) NOT NULL,
  `journeyPlanId` int(11) NOT NULL,
  `clientId` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `productName` varchar(255) NOT NULL,
  `productId` int(11) DEFAULT NULL,
  `totalItemsOnShelf` int(11) NOT NULL,
  `companyItemsOnShelf` int(11) NOT NULL,
  `comments` text DEFAULT NULL,
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `ShowOfShelfReport`
--

INSERT INTO `ShowOfShelfReport` (`id`, `journeyPlanId`, `clientId`, `userId`, `productName`, `productId`, `totalItemsOnShelf`, `companyItemsOnShelf`, `comments`, `createdAt`, `updatedAt`) VALUES
(1, 8033, 10653, 129, 'Coconut 100ml', 81, 20, 30, NULL, '2025-09-02 14:33:58', '2025-09-02 14:33:58'),
(2, 8045, 10730, 138, 'KCC Gold Crown TFA 500ml', 44, 180, 7, NULL, '2025-09-03 06:25:37', '2025-09-03 06:25:37'),
(3, 8065, 10748, 202, '', NULL, 21, 2, 'selling', '2025-09-03 07:44:38', '2025-09-03 07:44:38'),
(4, 8081, 10604, 94, 'Coconut 100ml', 81, 100, 2, 'this', '2025-09-04 04:51:10', '2025-09-04 04:51:10');

-- --------------------------------------------------------

--
-- Table structure for table `staff`
--

CREATE TABLE `staff` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `photo_url` varchar(255) NOT NULL,
  `empl_no` varchar(50) NOT NULL,
  `id_no` varchar(50) NOT NULL,
  `role` varchar(255) NOT NULL,
  `phone_number` varchar(50) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `department` varchar(100) DEFAULT NULL,
  `business_email` varchar(255) DEFAULT NULL,
  `department_email` varchar(255) DEFAULT NULL,
  `salary` decimal(11,2) DEFAULT NULL,
  `employment_type` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` int(3) NOT NULL,
  `avatar_url` varchar(200) NOT NULL,
  `status` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `staff`
--

INSERT INTO `staff` (`id`, `name`, `photo_url`, `empl_no`, `id_no`, `role`, `phone_number`, `password`, `department`, `business_email`, `department_email`, `salary`, `employment_type`, `created_at`, `updated_at`, `is_active`, `avatar_url`, `status`) VALUES
(1, 'Bryan', 'https://res.cloudinary.com/otienobryan/image/upload/v1755701940/staff_avatars/1_1755701939617_woosh_logo_sm.png.png', '1234', '34044', 'sales', '0706166875', '$2a$10$N9WBKL1nY1Eak7oGMGj7GuGJ3OswUj77MjPGqhNmiW7DxdQQA/2/S', NULL, NULL, NULL, 10.00, 'Permanent', '2025-07-09 13:48:06', '2025-08-26 15:16:40', 1, '', 1),
(2, 'Stanley Ngare', 'https://randomuser.me/api/portraits/lego/1.jpg', '44', '44', 'sales', '0790193623', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 45000.00, 'Permanent', '2025-07-09 13:48:09', '2025-08-27 06:05:04', 1, '', 1),
(3, 'Tanya Goes', 'https://randomuser.me/api/portraits/lego/1.jpg', '4', '4', 'sales', '0790193625', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 40000.00, 'Permanent', '2025-07-09 13:59:21', '2025-08-25 13:26:50', 1, '', 1),
(4, 'Allan Kasaine', '', 'TEST003', 'ID345678', 'stock', '0790123458', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 45000.00, 'Permanent', '2025-07-18 14:54:25', '2025-08-25 13:26:50', 1, '', 1),
(5, 'David Gichuhi', '', 'DEBUG001', '87654321', 'admin', '0790111111', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 30000.00, 'Contract', '2025-07-18 14:55:26', '2025-08-25 13:26:50', 1, '', 1),
(6, 'Mildred Mulama', '', 'TEST002', '11223344', 'hr', '0790222222', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 35000.00, 'Permanent', '2025-07-18 14:56:16', '2025-08-25 13:26:50', 1, '', 1),
(7, 'Stock', 'https://res.cloudinary.com/otienobryan/image/upload/v1755794118/staff_avatars/7_1755794117138_woosh_logo_sm.png.png', 'DEBUG002', '55667788', 'stock', '0790333333', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 40000.00, 'Contract', '2025-07-18 14:57:00', '2025-08-25 13:26:50', 1, '', 1),
(8, 'Mariah Wanyoike', 'uploads\\84947dc90b77fab27ce72ff4379f4543', 'EMP001', '1223', 'sales', NULL, '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, 0.00, '', '2025-07-18 15:29:37', '2025-08-25 13:26:50', 1, '', 1),
(9, 'admins', 'uploads\\403716d124ea35d28ba5c226e89fc8c9', '123355', '9', 'admin', NULL, '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, NULL, 'Permanent', '2025-07-19 12:38:19', '2025-08-25 13:26:50', 1, '', 1),
(11, 'Daniel Kabaya', '', '', '', 'admin', NULL, '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, NULL, 'Contract', '2025-08-12 12:55:55', '2025-08-25 13:26:50', 1, '', 1),
(12, 'Mohamed Ademba', '', '', '', 'admin', NULL, '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, NULL, '', '2025-08-12 14:18:08', '2025-08-25 13:26:50', 0, '', 1),
(13, 'Titus Okore', '', '', '', 'admin', NULL, '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', NULL, NULL, NULL, NULL, '', '2025-08-12 14:20:11', '2025-08-25 13:26:50', 0, '', 1),
(14, 'Faustine', 'https://randomuser.me/api/portraits/lego/1.jpg', 'EMP1755579401142', 'ID1755579401142', 'sales', '+1234567890', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', 'General', 'john.doe@company.com', NULL, 30000.00, 'Permanent', '2025-08-19 04:56:41', '2025-08-25 13:26:50', 1, '', 1);

-- --------------------------------------------------------

--
-- Table structure for table `staff_tasks`
--

CREATE TABLE `staff_tasks` (
  `id` int(11) NOT NULL,
  `title` varchar(191) NOT NULL,
  `description` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `completed_at` datetime DEFAULT NULL,
  `is_completed` tinyint(1) NOT NULL DEFAULT 0,
  `priority` varchar(50) NOT NULL DEFAULT 'medium',
  `status` varchar(50) NOT NULL DEFAULT 'pending',
  `staff_id` int(11) NOT NULL,
  `assigned_by_id` int(11) DEFAULT NULL,
  `due_date` datetime DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stock_takes`
--

CREATE TABLE `stock_takes` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `take_date` date NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `stock_takes`
--

INSERT INTO `stock_takes` (`id`, `store_id`, `staff_id`, `take_date`, `notes`, `created_at`) VALUES
(1, 1, 1, '2025-07-14', NULL, '2025-07-14 10:28:09'),
(2, 1, 1, '2025-08-19', NULL, '2025-08-19 08:25:24');

-- --------------------------------------------------------

--
-- Table structure for table `stock_take_items`
--

CREATE TABLE `stock_take_items` (
  `id` int(11) NOT NULL,
  `stock_take_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `system_quantity` int(11) NOT NULL,
  `counted_quantity` int(11) NOT NULL,
  `difference` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `stock_take_items`
--

INSERT INTO `stock_take_items` (`id`, `stock_take_id`, `product_id`, `system_quantity`, `counted_quantity`, `difference`) VALUES
(1, 1, 7, 1, 2, 1),
(2, 1, 10, 11, 1, -10),
(3, 1, 4, 2, 2, 0),
(4, 1, 6, 10, 10, 0),
(5, 2, 7, 618, 618, 0),
(6, 2, 6, 1, 1, 0),
(7, 2, 11, 103, 103, 0),
(8, 2, 16, 8, 8, 0),
(9, 2, 5, 0, 0, 0),
(10, 2, 43, 2, 2, 0),
(11, 2, 27, 768, 768, 0),
(12, 2, 22, 421, 421, 0),
(13, 2, 26, 275, 275, 0),
(14, 2, 21, 348, 348, 0),
(15, 2, 4, 5, 5, 0),
(16, 2, 40, 10, 10, 0),
(17, 2, 32, 21, 21, 0),
(18, 2, 12, 1, 1, 0),
(19, 2, 36, 2, 2, 0),
(20, 2, 10, 0, 0, 0),
(21, 2, 1, 137, 137, 0),
(22, 2, 37, 9, 9, 0),
(23, 2, 2, 2, 2, 0),
(24, 2, 41, 1, 1, 0),
(25, 2, 3, 0, 0, 0),
(26, 2, 30, 1076, 1076, 0),
(27, 2, 25, 826, 826, 0),
(28, 2, 38, 4, 4, 0),
(29, 2, 31, 34, 34, 0),
(30, 2, 8, 242, 242, 0),
(31, 2, 33, 51, 51, 0),
(32, 2, 9, 0, 0, 0),
(33, 2, 28, 904, 904, 0),
(34, 2, 23, 740, 740, 0),
(35, 2, 24, 778, 778, 0),
(36, 2, 29, 359, 359, 0),
(37, 2, 35, 18, 18, 0);

-- --------------------------------------------------------

--
-- Table structure for table `stores`
--

CREATE TABLE `stores` (
  `id` int(11) NOT NULL,
  `store_code` varchar(20) NOT NULL,
  `store_name` varchar(100) NOT NULL,
  `address` text DEFAULT NULL,
  `country_id` int(11) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `stores`
--

INSERT INTO `stores` (`id`, `store_code`, `store_name`, `address`, `country_id`, `is_active`, `created_at`) VALUES
(1, 'STORE1', 'Delta Corner', 'Delta Corner', 1, 1, '2025-07-06 08:37:36'),
(2, 'STORE2', 'Mombasa Road Store 1', 'Mombasa Road', 1, 1, '2025-07-06 08:37:36'),
(3, 'STORE3', 'Mombasa', 'Mombasa', 1, 1, '2025-07-06 08:37:36'),
(4, 'STORE4', 'Tanzania', 'Tanzania', 2, 1, '2025-07-06 08:37:36'),
(5, 'STORE5', 'Mombasa Road Store 2', 'Mombasa Road', 1, 1, '2025-07-30 09:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `store_inventory`
--

CREATE TABLE `store_inventory` (
  `id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `store_inventory`
--

INSERT INTO `store_inventory` (`id`, `store_id`, `product_id`, `quantity`, `updated_at`) VALUES
(1, 2, 1, 900, '2025-08-03 09:01:01'),
(2, 2, 2, 0, '2025-08-03 07:46:45'),
(4, 1, 10, 0, '2025-08-03 09:03:52'),
(5, 1, 7, 618, '2025-08-11 13:09:39'),
(8, 2, 6, 1, '2025-08-19 06:20:23'),
(9, 1, 4, 5, '2025-08-04 02:40:09'),
(11, 1, 6, 1, '2025-08-19 06:20:23'),
(13, 2, 9, 0, '2025-08-03 09:04:00'),
(15, 4, 8, 0, '2025-08-03 07:46:20'),
(16, 4, 9, 0, '2025-08-03 07:46:17'),
(17, 2, 7, 600, '2025-08-03 09:01:00'),
(20, 1, 5, 0, '2025-08-03 07:46:09'),
(21, 1, 21, 348, '2025-08-03 07:45:12'),
(22, 1, 22, 421, '2025-08-03 08:03:32'),
(23, 1, 25, 826, '2025-08-03 08:03:32'),
(24, 1, 23, 740, '2025-08-03 08:03:32'),
(25, 1, 24, 778, '2025-08-03 08:03:33'),
(26, 2, 22, 6400, '2025-08-03 08:06:07'),
(27, 2, 21, 14400, '2025-08-03 08:06:07'),
(28, 2, 25, 10800, '2025-08-03 08:06:07'),
(29, 2, 23, 11200, '2025-08-03 08:06:07'),
(30, 2, 24, 9200, '2025-08-03 08:06:07'),
(31, 1, 27, 768, '2025-08-03 08:14:06'),
(32, 1, 26, 275, '2025-08-09 10:21:43'),
(33, 1, 30, 1076, '2025-08-03 08:14:07'),
(34, 1, 28, 904, '2025-08-03 08:14:07'),
(35, 1, 29, 359, '2025-08-03 08:14:07'),
(36, 2, 27, 3600, '2025-08-03 08:15:23'),
(37, 2, 26, 13200, '2025-08-03 08:15:23'),
(38, 2, 30, 4000, '2025-08-03 08:15:23'),
(39, 2, 28, 4000, '2025-08-03 08:15:23'),
(40, 2, 29, 6400, '2025-08-03 08:15:23'),
(41, 1, 11, 103, '2025-08-03 08:58:51'),
(42, 1, 1, 137, '2025-08-03 08:58:51'),
(43, 1, 8, 242, '2025-08-03 08:58:51'),
(44, 2, 11, 0, '2025-08-03 09:04:09'),
(45, 2, 10, 0, '2025-08-03 09:04:13'),
(46, 2, 3, 0, '2025-08-03 09:04:17'),
(47, 2, 8, 1200, '2025-08-03 09:01:01'),
(48, 1, 3, 0, '2025-08-03 09:04:21'),
(49, 1, 9, 0, '2025-08-03 09:04:26'),
(50, 1, 16, 8, '2025-08-04 02:40:08'),
(51, 1, 12, 1, '2025-08-04 02:40:10'),
(52, 1, 2, 2, '2025-08-04 02:40:11'),
(53, 1, 40, 10, '2025-08-04 03:10:31'),
(54, 1, 32, 21, '2025-08-04 03:10:32'),
(55, 1, 36, 2, '2025-08-04 03:10:33'),
(56, 1, 37, 9, '2025-08-04 03:10:33'),
(57, 1, 41, 1, '2025-08-04 03:10:34'),
(58, 1, 38, 4, '2025-08-04 03:10:35'),
(59, 1, 31, 34, '2025-08-04 03:10:36'),
(60, 1, 33, 51, '2025-08-04 03:10:36'),
(61, 1, 35, 18, '2025-08-04 03:10:37'),
(62, 1, 43, 2, '2025-08-04 03:58:23'),
(63, 4, 34, 13, '2025-08-09 09:01:51'),
(66, 3, 18, 1, '2025-08-19 06:48:11');

-- --------------------------------------------------------

--
-- Table structure for table `suppliers`
--

CREATE TABLE `suppliers` (
  `id` int(11) NOT NULL,
  `supplier_code` varchar(20) NOT NULL,
  `company_name` varchar(100) NOT NULL,
  `contact_person` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `tax_id` varchar(50) DEFAULT NULL,
  `payment_terms` int(11) DEFAULT 30,
  `credit_limit` decimal(15,2) DEFAULT 0.00,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `suppliers`
--

INSERT INTO `suppliers` (`id`, `supplier_code`, `company_name`, `contact_person`, `email`, `phone`, `address`, `tax_id`, `payment_terms`, `credit_limit`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'SUP001', 'ABC Electronics', 'John Smith', 'john@abcelectronics.com', '0777', '123 Tech Street, Silicon Valley, CA 94025', 'PO', 30, 50000.00, 1, '2025-07-06 08:32:51', '2025-07-30 07:47:57'),
(2, 'SUP002', 'XYZ Manufacturing', 'Sarah Johnson', 'sarah@xyzmanufacturing.com', '+1-555-0102', '456 Industrial Blvd, Detroit, MI 48201', 'TAX789012', 45, 75000.00, 1, '2025-07-06 08:32:51', '2025-07-06 08:32:51'),
(3, 'SUP003', 'Global Parts Co.', 'Mike Chen', 'mike@globalparts.com', '+1-555-0103', '789 Parts Avenue, Chicago, IL 60601', 'TAX345678', 30, 100000.00, 1, '2025-07-06 08:32:52', '2025-07-06 08:32:52'),
(4, 'SUP004', 'Quality Supplies Ltd.', 'Lisa Brown', 'lisa@qualitysupplies.com', '+1-555-0104', '321 Quality Road, Boston, MA 02101', 'TAX901234', 60, 25000.00, 1, '2025-07-06 08:32:52', '2025-07-06 08:32:52'),
(5, 'SUP005', 'Premium Components', 'David Wilson', 'david@premiumcomponents.com', '+1-555-0105', '654 Premium Lane, Austin, TX 73301', 'TAX567890', 30, 150000.00, 1, '2025-07-06 08:32:52', '2025-07-06 08:32:52'),
(7, 'SUP0013', 'Highlands', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', '14300', 'PO33', 30, 2000.00, 1, '2025-07-17 12:23:41', '2025-07-17 12:23:41');

-- --------------------------------------------------------

--
-- Table structure for table `supplier_ledger`
--

CREATE TABLE `supplier_ledger` (
  `id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `date` datetime NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `reference_type` varchar(50) DEFAULT NULL,
  `reference_id` int(11) DEFAULT NULL,
  `debit` decimal(15,2) DEFAULT 0.00,
  `credit` decimal(15,2) DEFAULT 0.00,
  `running_balance` decimal(15,2) DEFAULT 0.00,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `supplier_ledger`
--

INSERT INTO `supplier_ledger` (`id`, `supplier_id`, `date`, `description`, `reference_type`, `reference_id`, `debit`, `credit`, `running_balance`, `created_at`) VALUES
(2, 3, '2025-07-06 18:48:46', 'Goods received for PO PO-000004', 'purchase_order', 4, 0.00, 200.00, 200.00, '2025-07-06 14:48:46'),
(3, 2, '2025-07-06 19:05:26', 'Goods received for PO PO-000005', 'purchase_order', 5, 0.00, 3719.88, 3719.88, '2025-07-06 15:05:26'),
(4, 2, '2025-07-06 00:00:00', 'Payment PAY-2-1751823340861', 'payment', 4, 370.00, 0.00, 3349.88, '2025-07-06 15:40:00'),
(5, 2, '2025-07-06 00:00:00', 'Payment PAY-2-1751822957518', 'payment', 2, 300.00, 0.00, 3419.88, '2025-07-06 15:40:38'),
(6, 2, '2025-07-06 00:00:00', 'Payment PAY-2-1751823164134', 'payment', 3, 400.00, 0.00, 3319.88, '2025-07-06 15:45:15'),
(8, 3, '2025-07-07 22:00:58', 'Goods received for PO PO-000006', 'purchase_order', 6, 0.00, 2000.00, 2200.00, '2025-07-07 18:00:58'),
(9, 3, '2025-07-07 22:13:24', 'Goods received for PO PO-000007', 'purchase_order', 7, 0.00, 4.00, 2204.00, '2025-07-07 18:13:24'),
(10, 1, '2025-07-12 11:00:08', 'Goods received for PO PO-000008', 'purchase_order', 8, 0.00, 600.00, 600.00, '2025-07-12 07:00:08'),
(11, 2, '2025-07-06 00:00:00', 'Payment PAY-2-1751822937737', 'payment', 1, 3719.88, 0.00, 0.00, '2025-07-12 08:17:33'),
(12, 3, '2025-07-12 00:00:00', 'Payment PAY-3-1752315446955', 'payment', 5, 200.00, 0.00, 2004.00, '2025-07-12 08:17:36'),
(13, 3, '2025-07-13 00:00:00', 'Payment PAY-3-1752401562561', 'payment', 6, 200.00, 0.00, 1804.00, '2025-07-13 08:13:28'),
(14, 3, '2025-07-13 00:00:00', 'Payment PAY-3-1752402940212', 'payment', 7, 120.00, 0.00, 1684.00, '2025-07-13 08:36:30'),
(15, 3, '2025-07-13 00:00:00', 'Payment PAY-3-1752403292029', 'payment', 8, 200.00, 0.00, 1484.00, '2025-07-13 08:41:37'),
(16, 1, '2025-07-14 11:55:10', 'Goods received for PO PO-000009', 'purchase_order', 9, 0.00, 299.98, 899.98, '2025-07-14 07:55:10'),
(17, 1, '2025-07-14 11:58:08', 'Goods received for PO PO-000010', 'purchase_order', 10, 0.00, 2000.00, 2899.98, '2025-07-14 07:58:08'),
(18, 1, '2025-07-22 13:31:33', 'Goods received for PO PO-000011', 'purchase_order', 11, 0.00, 3000.00, 5899.98, '2025-07-22 09:31:33'),
(19, 1, '2025-07-28 14:26:52', 'Goods received for PO PO-000012', 'purchase_order', 12, 0.00, 200.00, 6099.98, '2025-07-28 10:26:52'),
(20, 1, '2025-08-09 11:01:53', 'Goods received for PO PO-000014', 'purchase_order', 14, 0.00, 3900.00, 9999.98, '2025-08-09 09:01:53'),
(21, 1, '2025-08-09 12:21:43', 'Goods received for PO PO-000018', 'purchase_order', 18, 0.00, 300.00, 10299.98, '2025-08-09 10:21:43'),
(22, 3, '2025-08-09 00:00:00', 'Payment PAY-3-1754744593126-1 for PO PO-000007', 'payment', 9, 4.00, 0.00, 1480.00, '2025-08-09 13:03:12'),
(23, 3, '2025-08-09 00:00:00', 'Payment PAY-3-1754744747384-1 for PO PO-000006', 'payment', 10, 100.00, 0.00, 1380.00, '2025-08-09 13:05:46'),
(24, 1, '2025-08-19 08:48:11', 'Goods received for PO PO-000019', 'purchase_order', 19, 0.00, 200.00, 10499.98, '2025-08-19 06:48:11');

-- --------------------------------------------------------

--
-- Table structure for table `targets`
--

CREATE TABLE `targets` (
  `id` int(11) NOT NULL,
  `salesRepId` int(11) NOT NULL,
  `targetType` varchar(50) NOT NULL,
  `targetValue` int(11) NOT NULL,
  `currentValue` int(11) DEFAULT 0,
  `targetMonth` varchar(7) NOT NULL,
  `startDate` date NOT NULL,
  `endDate` date NOT NULL,
  `status` varchar(20) DEFAULT 'pending',
  `progress` int(11) DEFAULT 0,
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `tasks`
--

CREATE TABLE `tasks` (
  `id` int(11) NOT NULL,
  `title` varchar(191) NOT NULL,
  `description` text NOT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `completedAt` datetime(3) DEFAULT NULL,
  `isCompleted` tinyint(1) NOT NULL DEFAULT 0,
  `priority` varchar(191) NOT NULL DEFAULT 'medium',
  `status` varchar(191) NOT NULL DEFAULT 'pending',
  `salesRepId` int(11) NOT NULL,
  `assignedById` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tasks`
--

INSERT INTO `tasks` (`id`, `title`, `description`, `createdAt`, `completedAt`, `isCompleted`, `priority`, `status`, `salesRepId`, `assignedById`) VALUES
(13, 'd', 'dvbbmm', '2025-06-20 08:05:36.665', '2025-06-20 18:55:01.852', 1, 'High', 'completed', 94, 12),
(14, 'nn', 'nnn', '2025-06-25 17:26:12.387', '2025-08-02 17:24:25.320', 1, 'High', 'completed', 94, 12);

-- --------------------------------------------------------

--
-- Table structure for table `termination_letters`
--

CREATE TABLE `termination_letters` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `termination_date` date NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `termination_letters`
--

INSERT INTO `termination_letters` (`id`, `staff_id`, `file_name`, `file_url`, `termination_date`, `uploaded_at`) VALUES
(1, 8, 'id front.pdf', 'https://res.cloudinary.com/otienobryan/image/upload/v1753779750/termination_letters/8_1753779749522_id_front.pdf.pdf', '2025-07-29', '2025-07-29 07:02:30');

-- --------------------------------------------------------

--
-- Table structure for table `Token`
--

CREATE TABLE `Token` (
  `id` int(11) NOT NULL,
  `token` varchar(255) NOT NULL,
  `salesRepId` int(11) NOT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `expiresAt` datetime(3) NOT NULL,
  `blacklisted` tinyint(1) NOT NULL DEFAULT 0,
  `lastUsedAt` datetime(3) DEFAULT NULL,
  `tokenType` varchar(10) NOT NULL DEFAULT 'access'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Token`
--

INSERT INTO `Token` (`id`, `token`, `salesRepId`, `createdAt`, `expiresAt`, `blacklisted`, `lastUsedAt`, `tokenType`) VALUES
(1, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg1NDc5NSwiZXhwIjoxNzUzODgzNTk1fQ.mL7VNbTnMelyDlFtjUnUxlQCUKgW3bxmHD78SL-SELw', 94, '2025-07-30 05:53:15.054', '2025-07-30 13:53:15.052', 0, '2025-07-30 06:55:36.670', 'access'),
(2, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4NTQ3OTUsImV4cCI6MTc1NDQ1OTU5NX0.6i3z7olYnhoaErakNdFYrGXv6cVaWkphBrHsuqr3XxY', 94, '2025-07-30 05:53:15.054', '2025-08-06 05:53:15.052', 0, NULL, 'refresh'),
(3, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg2MDAxMiwiZXhwIjoxNzUzODg4ODEyfQ.Kc3sgDEc5J8PHHNANP9jJD9cDduEKfU5LlWMx5fjjoQ', 94, '2025-07-30 07:20:12.132', '2025-07-30 15:20:12.129', 0, '2025-07-30 07:48:14.047', 'access'),
(4, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4NjAwMTIsImV4cCI6MTc1NDQ2NDgxMn0.RaC1wTzio698nmCQUR7Q7IaZ6r3SavikxvmZkKOp7aw', 94, '2025-07-30 07:20:12.132', '2025-08-06 07:20:12.129', 0, NULL, 'refresh'),
(5, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg2MzIxMSwiZXhwIjoxNzUzODkyMDExfQ.JrWbldU7Zb9Df3AJJ9dqZ7udJdTNp0C2ORGd_UQBONo', 94, '2025-07-30 08:13:31.213', '2025-07-30 16:13:31.212', 1, '2025-07-30 15:39:08.442', 'access'),
(6, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4NjMyMTEsImV4cCI6MTc1NDQ2ODAxMX0.8HfRbL0IEiXS4vVQ-ReVC9SQJqcgxf8uNsA2VougM8M', 94, '2025-07-30 08:13:31.213', '2025-08-06 08:13:31.212', 0, NULL, 'refresh'),
(7, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg4OTk5MSwiZXhwIjoxNzUzOTE4NzkxfQ.ldYupgpifUvQiT7KfaeSjf-l8ZRE9JdB13Rs66VVfsQ', 94, '2025-07-30 15:39:51.089', '2025-07-30 23:39:51.085', 1, '2025-07-30 16:53:32.767', 'access'),
(8, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4ODk5OTEsImV4cCI6MTc1NDQ5NDc5MX0.DTLMJBYgcV5iYc1Covx7w6BvC0wETT4RlcBGkMGXNjo', 94, '2025-07-30 15:39:51.089', '2025-08-06 15:39:51.088', 0, NULL, 'refresh'),
(9, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg5MzcxMiwiZXhwIjoxNzUzOTIyNTEyfQ.8ad2tZZUOw656e18e1dsqYLK1xjb0Slo2q-e33zjy_E', 94, '2025-07-30 16:41:52.060', '2025-07-31 00:41:52.057', 0, NULL, 'access'),
(10, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4OTM3MTIsImV4cCI6MTc1NDQ5ODUxMn0.0XZpD4B9Dmo5SapqylnFS7bLmin9Z-Uy4k4VDNJH_Zg', 94, '2025-07-30 16:41:52.060', '2025-08-06 16:41:52.058', 0, NULL, 'refresh'),
(11, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg5Mzc3MCwiZXhwIjoxNzUzOTIyNTcwfQ.kpyRYoXj-WccORJSBuOe7VTi5X_DLjV6wqeToYKoS9E', 94, '2025-07-30 16:42:50.015', '2025-07-31 00:42:50.013', 0, '2025-07-30 16:42:52.620', 'access'),
(12, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4OTM3NzAsImV4cCI6MTc1NDQ5ODU3MH0.SW73VZCMiea0GEDcWl71JIZqMl1tXBxFeu3xClw18zM', 94, '2025-07-30 16:42:50.015', '2025-08-06 16:42:50.013', 0, NULL, 'refresh'),
(13, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg5NDQ0NCwiZXhwIjoxNzUzOTIzMjQ0fQ.gjgsca9YdcWbfD4poQhUuT9hMwB0wbqQdmmU_OH-Uqs', 94, '2025-07-30 16:54:04.238', '2025-07-31 00:54:04.235', 0, '2025-07-30 19:36:07.243', 'access'),
(14, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4OTQ0NDQsImV4cCI6MTc1NDQ5OTI0NH0.k3PMrBYRuk8Z8Z7GPV2NH-ChGZJPwlwZObrnQKAAL2A', 94, '2025-07-30 16:54:04.238', '2025-08-06 16:54:04.237', 0, NULL, 'refresh'),
(15, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg5NDgyMCwiZXhwIjoxNzUzOTIzNjIwfQ.TroB7nZPQFht-ad8M-p8lNbdf5LqloTeYawn7LaI9_A', 94, '2025-07-30 17:00:20.951', '2025-07-31 01:00:20.948', 0, '2025-07-30 17:00:24.013', 'access'),
(16, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4OTQ4MjAsImV4cCI6MTc1NDQ5OTYyMH0.NlOqeOSVzx-KY_MRuBv9ArizdKYcYWndqvfFh8YYTDc', 94, '2025-07-30 17:00:20.951', '2025-08-06 17:00:20.949', 0, NULL, 'refresh'),
(17, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzg5NTE5MCwiZXhwIjoxNzUzOTIzOTkwfQ.JIItzDUbcdMJQKZI92AroQ9ku_Baccg6U4JrvGO00ww', 94, '2025-07-30 17:06:30.370', '2025-07-31 01:06:30.368', 0, '2025-07-30 17:06:31.882', 'access'),
(18, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM4OTUxOTAsImV4cCI6MTc1NDQ5OTk5MH0.mct5jRigoWVDW9_5-teTod8920rXbYXbiDvzEViNOwM', 94, '2025-07-30 17:06:30.370', '2025-08-06 17:06:30.368', 0, NULL, 'refresh'),
(19, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1MzkwMjUyMCwiZXhwIjoxNzUzOTMxMzIwfQ.7CFYwHeebuB_1TuW_SFMJ4Ex6X-QFnehqpxW_Wd5uBQ', 94, '2025-07-30 19:08:40.324', '2025-07-31 03:08:40.318', 0, NULL, 'access'),
(20, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5MDI1MjAsImV4cCI6MTc1NDUwNzMyMH0.J6rpQBe8hnvDHkTeGqsqS4JftQSpEdpz0QvSX7VIgjc', 94, '2025-07-30 19:08:40.324', '2025-08-06 19:08:40.322', 0, NULL, 'refresh'),
(21, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1MzkwMjUyNywiZXhwIjoxNzUzOTMxMzI3fQ.e_ta2nXPED2yApyjnn5vZ_9Z9TEtJAssvlCM-OiCQoQ', 94, '2025-07-30 19:08:47.918', '2025-07-31 03:08:47.914', 0, '2025-07-30 19:12:12.029', 'access'),
(22, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5MDI1MjcsImV4cCI6MTc1NDUwNzMyN30.SKh6rnmlVvI5p5LAenfXBOfvVUesB_mocBeyoId2Tc8', 94, '2025-07-30 19:08:47.918', '2025-08-06 19:08:47.914', 0, NULL, 'refresh'),
(23, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk1NDgzMywiZXhwIjoxNzUzOTgzNjMzfQ.c9177l8nmZHZoAFFD98uGyXzjQbj_j--sog3QEUDNL0', 94, '2025-07-31 09:40:33.200', '2025-07-31 17:40:33.197', 0, NULL, 'access'),
(24, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NTQ4MzMsImV4cCI6MTc1NDU1OTYzM30.ZEpJkE3vSy0OzUUIcSq0P3meld8Xe3oMUhFYS8tqLX0', 94, '2025-07-31 09:40:33.200', '2025-08-07 09:40:33.197', 0, NULL, 'refresh'),
(25, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk1NTg5NCwiZXhwIjoxNzUzOTg0Njk0fQ.gEq7C0t6xixbs_VBkWlgIRyardla9bsj7Au4v1gjqPA', 94, '2025-07-31 09:58:14.969', '2025-07-31 17:58:14.965', 0, '2025-07-31 09:58:17.567', 'access'),
(26, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NTU4OTQsImV4cCI6MTc1NDU2MDY5NH0.OMN5Ql8fwY9P2BlHlCQhPEkqwG13WZrBQnz0DO_lDgw', 94, '2025-07-31 09:58:14.969', '2025-08-07 09:58:14.966', 0, NULL, 'refresh'),
(27, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk1NTk2NCwiZXhwIjoxNzUzOTg0NzY0fQ.iJMnRVEM1BsqkcIz4tMXfPqkyotwth9lYNsBBkUhVp0', 94, '2025-07-31 09:59:24.797', '2025-07-31 17:59:24.795', 0, '2025-07-31 09:59:33.724', 'access'),
(28, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NTU5NjQsImV4cCI6MTc1NDU2MDc2NH0.6I-RY3_kbsrGDim7QIMOm5unnu0ywhFAJwo6X6C4nLw', 94, '2025-07-31 09:59:24.797', '2025-08-07 09:59:24.795', 0, NULL, 'refresh'),
(29, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NDYyMSwiZXhwIjoxNzU0MDAzNDIxfQ.dt5N1rt_ZPGDvAkyaiFigUNAY1zgoKM7QDkYd4cQYuI', 94, '2025-07-31 15:10:21.957', '2025-07-31 23:10:21.955', 0, '2025-07-31 15:10:25.062', 'access'),
(30, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzQ2MjEsImV4cCI6MTc1NDU3OTQyMX0.ZjAlrXOuC-jnIhoHalBcB8rfMHIuv2XUOIbnQGesGpo', 94, '2025-07-31 15:10:21.957', '2025-08-07 15:10:21.955', 0, NULL, 'refresh'),
(31, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NTA5NiwiZXhwIjoxNzU0MDAzODk2fQ.5GdfkhyuSXOs1vLfLOWpSGOyY_T5d4zJnQh2zAV7j2Q', 94, '2025-07-31 15:18:16.231', '2025-07-31 23:18:16.230', 0, '2025-07-31 15:18:18.943', 'access'),
(32, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzUwOTYsImV4cCI6MTc1NDU3OTg5Nn0.d0d4uLri8h4iZ8e1djZB5xlpkq-NDHG8ZSzsHqQ9RPI', 94, '2025-07-31 15:18:16.231', '2025-08-07 15:18:16.230', 0, NULL, 'refresh'),
(33, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NTE0NCwiZXhwIjoxNzU0MDAzOTQ0fQ.1HAqS_0sAb8UE0_q9QwrZMAnGObzXiPup5pPUMXzIf8', 94, '2025-07-31 15:19:04.334', '2025-07-31 23:19:04.333', 0, '2025-07-31 15:19:04.966', 'access'),
(34, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzUxNDQsImV4cCI6MTc1NDU3OTk0NH0.WnloBo5ChLvFQSxbRjRcGX6W55qaJ05KpvBPX9DG_4o', 94, '2025-07-31 15:19:04.334', '2025-08-07 15:19:04.333', 0, NULL, 'refresh'),
(35, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NTI1NCwiZXhwIjoxNzU0MDA0MDU0fQ.71iZUa47el-gX8k6UrnGVYg5gi34VvcmPyj4nsc5rIM', 94, '2025-07-31 15:20:54.086', '2025-07-31 23:20:54.085', 0, '2025-07-31 15:20:54.827', 'access'),
(36, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzUyNTQsImV4cCI6MTc1NDU4MDA1NH0.oAaP0eFx1p39ZK0pKvFe_ruJ136j7rmcXuzi7MSK0z4', 94, '2025-07-31 15:20:54.086', '2025-08-07 15:20:54.085', 0, NULL, 'refresh'),
(37, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NTI3MiwiZXhwIjoxNzU0MDA0MDcyfQ.P59n5nLNDGRoGOjFBW4S6H_YiumJw0u4_CqWQJt83YM', 94, '2025-07-31 15:21:12.115', '2025-07-31 23:21:12.113', 0, '2025-07-31 15:21:13.553', 'access'),
(38, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzUyNzIsImV4cCI6MTc1NDU4MDA3Mn0.tlbDlUx-KIqF-Kb_767F-3I4CXCXpTTnF5MglDPQSkQ', 94, '2025-07-31 15:21:12.115', '2025-08-07 15:21:12.113', 0, NULL, 'refresh'),
(39, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk3NzE4MywiZXhwIjoxNzU0MDA1OTgzfQ.XsEVIZ6n864o5mM6YdBnx4VEwoqhHVZPm4oH1faU0lY', 94, '2025-07-31 15:53:03.500', '2025-07-31 23:53:03.497', 1, '2025-07-31 18:57:55.136', 'access'),
(40, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5NzcxODMsImV4cCI6MTc1NDU4MTk4M30.2Qt0ScXP8YYv3vKCbEc8cdzMecY6RlBsQ1sgyT3KoJ8', 94, '2025-07-31 15:53:03.500', '2025-08-07 15:53:03.497', 0, NULL, 'refresh'),
(41, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk4ODI5OSwiZXhwIjoxNzU0MDE3MDk5fQ.CKXBYzRCDSEkxxEdOUUpPYCkD0UIYvxi-C7xB5I7Dnw', 94, '2025-07-31 18:58:19.985', '2025-08-01 02:58:19.983', 0, '2025-07-31 19:12:53.264', 'access'),
(42, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5ODgyOTksImV4cCI6MTc1NDU5MzA5OX0.mt2X8lpCYx1LW9bcCkP96dfKZi0iThpGZ3lvVyEkaZ0', 94, '2025-07-31 18:58:19.985', '2025-08-07 18:58:19.984', 0, NULL, 'refresh'),
(43, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk4OTg3NCwiZXhwIjoxNzU0MDE4Njc0fQ.-rKQleNj6RGm2QKxAKxolNVQAu1Kwumey9GFgKvyB-M', 94, '2025-07-31 19:24:34.648', '2025-08-01 03:24:34.647', 1, '2025-07-31 20:40:03.375', 'access'),
(44, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5ODk4NzQsImV4cCI6MTc1NDU5NDY3NH0.bxqn3LQohJg1CmSTQO1TowNp_oumGF3snoo633ReUrg', 94, '2025-07-31 19:24:34.648', '2025-08-07 19:24:34.647', 0, NULL, 'refresh'),
(45, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc1Mzk5NDQyMywiZXhwIjoxNzU0MDIzMjIzfQ.RbHxijRnfywC9H-K87a3xPUCrF2MgnPZ1m9uhaZeVwo', 94, '2025-07-31 20:40:23.726', '2025-08-01 04:40:23.724', 0, '2025-07-31 22:07:32.784', 'access'),
(46, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjk0LCJyb2xlIjoiU0FMRVNfUkVQIiwidHlwZSI6InJlZnJlc2giLCJpYXQiOjE3NTM5OTQ0MjMsImV4cCI6MTc1NDU5OTIyM30.SBbdo4LEELX27ao-DvofBzK0iC73mopJ9pWtQFMaGrE', 94, '2025-07-31 20:40:23.726', '2025-08-07 20:40:23.725', 0, NULL, 'refresh');

-- --------------------------------------------------------

--
-- Table structure for table `UpliftSale`
--

CREATE TABLE `UpliftSale` (
  `id` int(11) NOT NULL,
  `clientId` int(11) NOT NULL,
  `userId` int(11) NOT NULL,
  `status` varchar(191) NOT NULL DEFAULT 'pending',
  `totalAmount` double NOT NULL DEFAULT 0,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `updatedAt` datetime(3) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `UpliftSale`
--

INSERT INTO `UpliftSale` (`id`, `clientId`, `userId`, `status`, `totalAmount`, `createdAt`, `updatedAt`) VALUES
(3, 689, 52, 'pending', 2380, '2025-05-08 12:52:18.455', '2025-05-08 12:52:20.288'),
(13, 246, 46, 'pending', 18750, '2025-05-27 09:41:02.778', '2025-05-27 09:41:06.085'),
(15, 2325, 94, 'pending', 300, '2025-06-17 07:59:18.359', '2025-06-17 07:59:20.963'),
(16, 2159, 94, 'pending', 5000, '2025-06-19 17:43:53.341', '2025-06-19 17:43:55.525'),
(17, 2204, 94, 'pending', 23, '2025-07-04 06:07:16.204', '2025-07-04 06:07:18.535'),
(18, 2221, 94, 'pending', 900, '2025-07-31 21:54:32.919', '2025-07-31 21:54:32.915'),
(19, 298, 94, 'pending', 0, '2025-08-02 22:34:18.676', '0000-00-00 00:00:00.000'),
(20, 1796, 94, 'pending', 0, '2025-08-25 14:21:32.676', '0000-00-00 00:00:00.000');

-- --------------------------------------------------------

--
-- Table structure for table `UpliftSaleItem`
--

CREATE TABLE `UpliftSaleItem` (
  `id` int(11) NOT NULL,
  `upliftSaleId` int(11) NOT NULL,
  `productId` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unitPrice` double NOT NULL,
  `total` double NOT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `UpliftSaleItem`
--

INSERT INTO `UpliftSaleItem` (`id`, `upliftSaleId`, `productId`, `quantity`, `unitPrice`, `total`, `createdAt`) VALUES
(3, 3, 19, 7, 340, 2380, '2025-05-08 12:52:19.555'),
(15, 13, 2, 3, 1250, 3750, '2025-05-27 09:41:03.885'),
(16, 13, 3, 3, 1250, 3750, '2025-05-27 09:41:03.885'),
(17, 13, 7, 3, 1250, 3750, '2025-05-27 09:41:03.885'),
(18, 13, 4, 3, 1250, 3750, '2025-05-27 09:41:03.885'),
(19, 13, 1, 3, 1250, 3750, '2025-05-27 09:41:03.885'),
(21, 15, 15, 2, 100, 200, '2025-06-17 07:59:19.543'),
(22, 15, 8, 1, 100, 100, '2025-06-17 07:59:19.543'),
(23, 16, 10, 1, 2000, 2000, '2025-06-19 17:43:54.435'),
(24, 16, 9, 1, 3000, 3000, '2025-06-19 17:43:54.435'),
(25, 17, 15, 1, 23, 23, '2025-07-04 06:07:17.602'),
(26, 18, 7, 1, 900, 900, '2025-07-31 21:54:33.339');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `role` enum('admin','user','rider') DEFAULT 'user',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `avatar_url` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `password_hash`, `full_name`, `role`, `is_active`, `created_at`, `updated_at`, `avatar_url`) VALUES
(1, 'admin', 'admin@retailfinance.com', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', 'System Administrator', 'admin', 1, '2025-07-06 07:58:31', '2025-07-06 09:30:45', ''),
(2, 'hr', 'hr@woosh.com', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', 'HR', '', 1, '2025-07-09 12:59:04', '2025-07-09 13:01:36', ''),
(3, 'sales', 'sales@woosh.com', '$2a$10$6TaWIl2O8CEHG5kLNir0fOuLEJPJukcKYud2fZQpbt7/KnKgJS3R6', 'Sales', '', 1, '2025-07-17 18:57:53', '2025-07-19 11:33:51', 'https://res.cloudinary.com/otienobryan/image/upload/v1752932031/avatars/t016eqdh8z9qu04kdx2e.png');

-- --------------------------------------------------------

--
-- Table structure for table `user_devices`
--

CREATE TABLE `user_devices` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `device_id` varchar(100) NOT NULL,
  `device_name` varchar(100) DEFAULT NULL,
  `device_type` enum('android','ios','web') NOT NULL,
  `device_model` varchar(100) DEFAULT NULL,
  `os_version` varchar(50) DEFAULT NULL,
  `app_version` varchar(20) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 0,
  `last_used` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User device registration for attendance security. is_active: 0=pending approval, 1=approved';

--
-- Dumping data for table `user_devices`
--

INSERT INTO `user_devices` (`id`, `user_id`, `device_id`, `device_name`, `device_type`, `device_model`, `os_version`, `app_version`, `ip_address`, `is_active`, `last_used`, `created_at`, `updated_at`) VALUES
(3, 1, 'ios_6C6B4780-9C73-4C0E-9F51-6A0D95045117', 'iPhone iPhone', 'ios', 'iPhone', 'iOS 18.5', '1.0.0', '192.168.100.15', 1, '2025-07-20 16:30:11', '2025-07-20 11:42:10', '2025-07-20 15:30:11');

-- --------------------------------------------------------

--
-- Table structure for table `versions`
--

CREATE TABLE `versions` (
  `id` int(11) NOT NULL,
  `version` varchar(20) NOT NULL,
  `build_number` int(11) NOT NULL,
  `min_required_version` varchar(20) DEFAULT '1.0.0',
  `force_update` tinyint(1) DEFAULT 0,
  `update_message` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `versions`
--

INSERT INTO `versions` (`id`, `version`, `build_number`, `min_required_version`, `force_update`, `update_message`, `is_active`, `created_at`) VALUES
(1, '1.0.4', 2, '1.0.0', 0, 'Current stable version', NULL, '2025-08-02 20:19:31');

-- --------------------------------------------------------

--
-- Table structure for table `VisibilityReport`
--

CREATE TABLE `VisibilityReport` (
  `reportId` int(11) DEFAULT NULL,
  `comment` varchar(191) DEFAULT NULL,
  `imageUrl` varchar(191) DEFAULT NULL,
  `createdAt` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  `clientId` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  `userId` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `VisibilityReport`
--

INSERT INTO `VisibilityReport` (`reportId`, `comment`, `imageUrl`, `createdAt`, `clientId`, `id`, `userId`) VALUES
(NULL, 'test', NULL, '2025-09-02 16:34:38.408', 10653, 4444, 129),
(NULL, 'uht display', NULL, '2025-09-03 08:23:48.354', 10730, 4445, 138),
(NULL, 'Ghee', NULL, '2025-09-03 09:02:52.867', 10728, 4446, 178),
(NULL, 'done', NULL, '2025-09-03 09:43:58.127', 10748, 4447, 202);

-- --------------------------------------------------------

--
-- Table structure for table `warning_letters`
--

CREATE TABLE `warning_letters` (
  `id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `warning_date` date NOT NULL,
  `warning_type` varchar(50) NOT NULL,
  `description` text DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `warning_letters`
--

INSERT INTO `warning_letters` (`id`, `staff_id`, `file_name`, `file_url`, `warning_date`, `warning_type`, `description`, `uploaded_at`) VALUES
(1, 9, 'logo_maa.pdf', 'https://res.cloudinary.com/otienobryan/image/upload/v1753781704/warning_letters/9_1753781704362_logo_maa.pdf.pdf', '2025-07-29', 'First Warning', 'test', '2025-07-29 07:35:04');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `account_category`
--
ALTER TABLE `account_category`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `account_ledger`
--
ALTER TABLE `account_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `account_id` (`account_id`);

--
-- Indexes for table `account_types`
--
ALTER TABLE `account_types`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `allowed_ips`
--
ALTER TABLE `allowed_ips`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_ip_address` (`ip_address`),
  ADD KEY `idx_is_active` (`is_active`);

--
-- Indexes for table `assets`
--
ALTER TABLE `assets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `account_id` (`account_id`);

--
-- Indexes for table `asset_assignments`
--
ALTER TABLE `asset_assignments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `assigned_by` (`assigned_by`),
  ADD KEY `idx_asset_id` (`asset_id`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_assigned_date` (`assigned_date`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_asset_staff` (`asset_id`,`staff_id`);

--
-- Indexes for table `asset_types`
--
ALTER TABLE `asset_types`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `attendance`
--
ALTER TABLE `attendance`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_staff_date` (`staff_id`,`date`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_date` (`date`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_checkin_time` (`checkin_time`),
  ADD KEY `idx_checkout_time` (`checkout_time`),
  ADD KEY `idx_staff_date_range` (`staff_id`,`date`),
  ADD KEY `idx_attendance_staff_status` (`staff_id`,`status`),
  ADD KEY `idx_attendance_date_status` (`date`,`status`),
  ADD KEY `idx_attendance_created_at` (`created_at`);

--
-- Indexes for table `Category`
--
ALTER TABLE `Category`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `CategoryPriceOption`
--
ALTER TABLE `CategoryPriceOption`
  ADD PRIMARY KEY (`id`),
  ADD KEY `category_id` (`category_id`);

--
-- Indexes for table `chart_of_accounts`
--
ALTER TABLE `chart_of_accounts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `chart_of_accounts1`
--
ALTER TABLE `chart_of_accounts1`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `account_code` (`account_code`),
  ADD KEY `parent_account_id` (`parent_account_id`);

--
-- Indexes for table `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `room_id` (`room_id`),
  ADD KEY `sender_id` (`sender_id`);

--
-- Indexes for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `chat_room_members`
--
ALTER TABLE `chat_room_members`
  ADD PRIMARY KEY (`id`),
  ADD KEY `room_id` (`room_id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `ClientAssignment`
--
ALTER TABLE `ClientAssignment`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ClientAssignment_outletId_salesRepId_key` (`outletId`,`salesRepId`),
  ADD KEY `ClientAssignment_salesRepId_idx` (`salesRepId`),
  ADD KEY `ClientAssignment_outletId_idx` (`outletId`);

--
-- Indexes for table `Clients`
--
ALTER TABLE `Clients`
  ADD PRIMARY KEY (`id`),
  ADD KEY `Clients_countryId_fkey` (`countryId`),
  ADD KEY `Clients_countryId_status_route_id_idx` (`countryId`,`status`,`route_id`);

--
-- Indexes for table `client_ledger`
--
ALTER TABLE `client_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_client_ledger_client` (`client_id`);

--
-- Indexes for table `client_payments`
--
ALTER TABLE `client_payments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_client_payments_account` (`account_id`);

--
-- Indexes for table `Country`
--
ALTER TABLE `Country`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `credit_notes`
--
ALTER TABLE `credit_notes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `credit_note_number` (`credit_note_number`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_credit_note_date` (`credit_note_date`),
  ADD KEY `idx_credit_note_number` (`credit_note_number`);

--
-- Indexes for table `credit_note_items`
--
ALTER TABLE `credit_note_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_credit_note_id` (`credit_note_id`),
  ADD KEY `idx_invoice_id` (`invoice_id`),
  ADD KEY `idx_product_id` (`product_id`);

--
-- Indexes for table `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `customer_code` (`customer_code`),
  ADD KEY `country_id` (`country_id`),
  ADD KEY `region_id` (`region_id`),
  ADD KEY `route_id` (`route_id`);

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `distributors_targets`
--
ALTER TABLE `distributors_targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_rep_id` (`sales_rep_id`);

--
-- Indexes for table `documents`
--
ALTER TABLE `documents`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `employee_contracts`
--
ALTER TABLE `employee_contracts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`),
  ADD KEY `renewed_from` (`renewed_from`);

--
-- Indexes for table `employee_documents`
--
ALTER TABLE `employee_documents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `employee_warnings`
--
ALTER TABLE `employee_warnings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `faulty_products_items`
--
ALTER TABLE `faulty_products_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_report_id` (`report_id`),
  ADD KEY `idx_product_id` (`product_id`);

--
-- Indexes for table `faulty_products_reports`
--
ALTER TABLE `faulty_products_reports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_store_id` (`store_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_reported_date` (`reported_date`),
  ADD KEY `idx_reported_by` (`reported_by`),
  ADD KEY `idx_assigned_to` (`assigned_to`);

--
-- Indexes for table `FeedbackReport`
--
ALTER TABLE `FeedbackReport`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `FeedbackReport_reportId_key` (`reportId`),
  ADD KEY `FeedbackReport_userId_idx` (`userId`),
  ADD KEY `FeedbackReport_clientId_idx` (`clientId`),
  ADD KEY `FeedbackReport_reportId_idx` (`reportId`);

--
-- Indexes for table `hr_calendar_tasks`
--
ALTER TABLE `hr_calendar_tasks`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `inventory_receipts`
--
ALTER TABLE `inventory_receipts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `purchase_order_id` (`purchase_order_id`),
  ADD KEY `product_id` (`product_id`),
  ADD KEY `store_id` (`store_id`),
  ADD KEY `fk_inventory_receipts_received_by` (`received_by`);

--
-- Indexes for table `inventory_transactions`
--
ALTER TABLE `inventory_transactions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `product_id` (`product_id`),
  ADD KEY `store_id` (`store_id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `inventory_transfers`
--
ALTER TABLE `inventory_transfers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `from_store_id` (`from_store_id`),
  ADD KEY `to_store_id` (`to_store_id`),
  ADD KEY `product_id` (`product_id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `journal_entries`
--
ALTER TABLE `journal_entries`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `entry_number` (`entry_number`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `journal_entry_lines`
--
ALTER TABLE `journal_entry_lines`
  ADD PRIMARY KEY (`id`),
  ADD KEY `journal_entry_id` (`journal_entry_id`),
  ADD KEY `account_id` (`account_id`);

--
-- Indexes for table `JourneyPlan`
--
ALTER TABLE `JourneyPlan`
  ADD PRIMARY KEY (`id`),
  ADD KEY `JourneyPlan_routeId_fkey` (`routeId`);

--
-- Indexes for table `key_account_targets`
--
ALTER TABLE `key_account_targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_rep_id` (`sales_rep_id`);

--
-- Indexes for table `leaves`
--
ALTER TABLE `leaves`
  ADD PRIMARY KEY (`id`),
  ADD KEY `leaves_userId_fkey` (`userId`);

--
-- Indexes for table `leave_balances`
--
ALTER TABLE `leave_balances`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_employee_leave_type_year` (`employee_id`,`leave_type_id`,`year`),
  ADD KEY `idx_employee_id` (`employee_id`),
  ADD KEY `idx_leave_type_id` (`leave_type_id`),
  ADD KEY `idx_year` (`year`),
  ADD KEY `idx_employee_year` (`employee_id`,`year`),
  ADD KEY `idx_leave_balances_employee_type` (`employee_id`,`leave_type_id`),
  ADD KEY `idx_leave_balances_year_type` (`year`,`leave_type_id`);

--
-- Indexes for table `leave_requests`
--
ALTER TABLE `leave_requests`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_employee_leave_overlap` (`employee_id`,`leave_type_id`,`start_date`,`end_date`),
  ADD KEY `idx_employee_id` (`employee_id`),
  ADD KEY `idx_leave_type_id` (`leave_type_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_start_date` (`start_date`),
  ADD KEY `idx_end_date` (`end_date`),
  ADD KEY `idx_approved_by` (`approved_by`),
  ADD KEY `idx_employee_status` (`employee_id`,`status`),
  ADD KEY `idx_date_range` (`start_date`,`end_date`),
  ADD KEY `idx_leave_requests_employee_status_date` (`employee_id`,`status`,`start_date`),
  ADD KEY `idx_leave_requests_type_status` (`leave_type_id`,`status`),
  ADD KEY `idx_leave_requests_created_at` (`created_at`),
  ADD KEY `leave_requests_salesrep_id_fkey` (`salesrep`);

--
-- Indexes for table `leave_types`
--
ALTER TABLE `leave_types`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_is_active` (`is_active`),
  ADD KEY `idx_name` (`name`);

--
-- Indexes for table `LoginHistory`
--
ALTER TABLE `LoginHistory`
  ADD PRIMARY KEY (`id`),
  ADD KEY `LoginHistory_userId_idx` (`userId`),
  ADD KEY `LoginHistory_userId_status_idx` (`userId`,`status`),
  ADD KEY `LoginHistory_sessionStart_idx` (`sessionStart`),
  ADD KEY `LoginHistory_sessionEnd_idx` (`sessionEnd`),
  ADD KEY `LoginHistory_userId_sessionStart_idx` (`userId`,`sessionStart`),
  ADD KEY `LoginHistory_status_sessionStart_idx` (`status`,`sessionStart`),
  ADD KEY `idx_login_history_user_id` (`userId`),
  ADD KEY `idx_login_history_session_start` (`sessionStart`),
  ADD KEY `idx_login_history_session_end` (`sessionEnd`);

--
-- Indexes for table `managers`
--
ALTER TABLE `managers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `merchandise`
--
ALTER TABLE `merchandise`
  ADD PRIMARY KEY (`id`),
  ADD KEY `category_id` (`category_id`),
  ADD KEY `idx_merchandise_active` (`is_active`),
  ADD KEY `idx_merchandise_name` (`name`);

--
-- Indexes for table `merchandise_assignments`
--
ALTER TABLE `merchandise_assignments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_merchandise_id` (`merchandise_id`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_date_assigned` (`date_assigned`);

--
-- Indexes for table `merchandise_categories`
--
ALTER TABLE `merchandise_categories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`),
  ADD KEY `idx_merchandise_categories_active` (`is_active`);

--
-- Indexes for table `merchandise_ledger`
--
ALTER TABLE `merchandise_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_merchandise_ledger_merchandise` (`merchandise_id`),
  ADD KEY `idx_merchandise_ledger_store` (`store_id`),
  ADD KEY `idx_merchandise_ledger_type` (`transaction_type`),
  ADD KEY `idx_merchandise_ledger_date` (`created_at`);

--
-- Indexes for table `merchandise_stock`
--
ALTER TABLE `merchandise_stock`
  ADD PRIMARY KEY (`id`),
  ADD KEY `store_id` (`store_id`),
  ADD KEY `idx_merchandise_stock_merchandise` (`merchandise_id`),
  ADD KEY `idx_merchandise_stock_active` (`is_active`),
  ADD KEY `idx_merchandise_stock_date` (`received_date`);

--
-- Indexes for table `my_assets`
--
ALTER TABLE `my_assets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `asset_code` (`asset_code`),
  ADD KEY `idx_asset_code` (`asset_code`),
  ADD KEY `idx_asset_type` (`asset_type`),
  ADD KEY `idx_supplier_id` (`supplier_id`),
  ADD KEY `idx_purchase_date` (`purchase_date`),
  ADD KEY `idx_location` (`location`);

--
-- Indexes for table `my_order`
--
ALTER TABLE `my_order`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `so_number` (`so_number`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `fk_sales_orders_client` (`client_id`);

--
-- Indexes for table `my_order_items`
--
ALTER TABLE `my_order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_order_id` (`my_order_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `my_receipts`
--
ALTER TABLE `my_receipts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `supplier_id` (`supplier_id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `non_supplies`
--
ALTER TABLE `non_supplies`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ProductReport_userId_idx` (`userId`),
  ADD KEY `ProductReport_clientId_idx` (`clientId`),
  ADD KEY `ProductReport_reportId_idx` (`reportId`);

--
-- Indexes for table `NoticeBoard`
--
ALTER TABLE `NoticeBoard`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `notices`
--
ALTER TABLE `notices`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `outlet_categories`
--
ALTER TABLE `outlet_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `out_of_office_requests`
--
ALTER TABLE `out_of_office_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `payment_number` (`payment_number`),
  ADD KEY `supplier_id` (`supplier_id`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `fk_payments_purchase_order` (`purchase_order_id`);

--
-- Indexes for table `payroll_history`
--
ALTER TABLE `payroll_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `Product`
--
ALTER TABLE `Product`
  ADD PRIMARY KEY (`id`),
  ADD KEY `Product_clientId_fkey` (`clientId`);

--
-- Indexes for table `ProductExpiryReport`
--
ALTER TABLE `ProductExpiryReport`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ProductExpiryReport_journeyPlanId_idx` (`journeyPlanId`),
  ADD KEY `ProductExpiryReport_clientId_idx` (`clientId`),
  ADD KEY `ProductExpiryReport_userId_idx` (`userId`),
  ADD KEY `ProductExpiryReport_expiryDate_idx` (`expiryDate`),
  ADD KEY `ProductExpiryReport_productId_idx` (`productId`);

--
-- Indexes for table `ProductReport`
--
ALTER TABLE `ProductReport`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ProductReport_userId_idx` (`userId`),
  ADD KEY `ProductReport_clientId_idx` (`clientId`),
  ADD KEY `ProductReport_reportId_idx` (`reportId`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `product_code` (`product_code`);

--
-- Indexes for table `purchase_orders`
--
ALTER TABLE `purchase_orders`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `po_number` (`po_number`),
  ADD KEY `supplier_id` (`supplier_id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `purchase_order_items`
--
ALTER TABLE `purchase_order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `purchase_order_id` (`purchase_order_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `receipts`
--
ALTER TABLE `receipts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `receipt_number` (`receipt_number`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `fk_receipts_sales_order` (`sales_order_id`),
  ADD KEY `fk_receipts_client` (`client_id`);

--
-- Indexes for table `Regions`
--
ALTER TABLE `Regions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `Regions_name_countryId_key` (`name`,`countryId`),
  ADD KEY `Regions_countryId_fkey` (`countryId`);

--
-- Indexes for table `retail_targets`
--
ALTER TABLE `retail_targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_rep_id` (`sales_rep_id`);

--
-- Indexes for table `Riders`
--
ALTER TABLE `Riders`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `riders_company`
--
ALTER TABLE `riders_company`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `routes`
--
ALTER TABLE `routes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `salesclient_payment`
--
ALTER TABLE `salesclient_payment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ClientPayment_clientId_fkey` (`clientId`),
  ADD KEY `ClientPayment_userId_fkey` (`salesrepId`);

--
-- Indexes for table `SalesRep`
--
ALTER TABLE `SalesRep`
  ADD PRIMARY KEY (`id`),
  ADD KEY `SalesRep_countryId_fkey` (`countryId`),
  ADD KEY `idx_status_role` (`status`,`role`),
  ADD KEY `idx_location` (`countryId`,`region_id`,`route_id`),
  ADD KEY `idx_manager` (`managerId`);

--
-- Indexes for table `sales_orders`
--
ALTER TABLE `sales_orders`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `so_number` (`so_number`),
  ADD KEY `fk_sales_orders_client` (`client_id`),
  ADD KEY `salesrep_rel` (`salesrep`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `idx_sales_orders_delivery_image` (`delivery_image`);

--
-- Indexes for table `sales_order_items`
--
ALTER TABLE `sales_order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_order_id` (`sales_order_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `sales_rep_managers`
--
ALTER TABLE `sales_rep_managers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sales_rep_id` (`sales_rep_id`),
  ADD KEY `manager_id` (`manager_id`);

--
-- Indexes for table `sales_rep_manager_assignments`
--
ALTER TABLE `sales_rep_manager_assignments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_assignment` (`sales_rep_id`,`manager_type`),
  ADD KEY `manager_id` (`manager_id`);

--
-- Indexes for table `ShowOfShelfReport`
--
ALTER TABLE `ShowOfShelfReport`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ShowOfShelfReport_journeyPlanId_idx` (`journeyPlanId`),
  ADD KEY `ShowOfShelfReport_clientId_idx` (`clientId`),
  ADD KEY `ShowOfShelfReport_userId_idx` (`userId`),
  ADD KEY `ShowOfShelfReport_productId_idx` (`productId`);

--
-- Indexes for table `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `staff_tasks`
--
ALTER TABLE `staff_tasks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_assigned_by_id` (`assigned_by_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_priority` (`priority`);

--
-- Indexes for table `stock_takes`
--
ALTER TABLE `stock_takes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `store_id` (`store_id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `stock_take_items`
--
ALTER TABLE `stock_take_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `stock_take_id` (`stock_take_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `stores`
--
ALTER TABLE `stores`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `store_code` (`store_code`),
  ADD KEY `country_re` (`country_id`);

--
-- Indexes for table `store_inventory`
--
ALTER TABLE `store_inventory`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `store_id` (`store_id`,`product_id`),
  ADD KEY `product_id` (`product_id`);

--
-- Indexes for table `suppliers`
--
ALTER TABLE `suppliers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `supplier_code` (`supplier_code`);

--
-- Indexes for table `supplier_ledger`
--
ALTER TABLE `supplier_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `supplier_id` (`supplier_id`);

--
-- Indexes for table `targets`
--
ALTER TABLE `targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_salesRepId` (`salesRepId`),
  ADD KEY `idx_targetType` (`targetType`),
  ADD KEY `idx_targetMonth` (`targetMonth`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `tasks_assignedById_idx` (`assignedById`),
  ADD KEY `tasks_salesRepId_fkey` (`salesRepId`);

--
-- Indexes for table `termination_letters`
--
ALTER TABLE `termination_letters`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `Token`
--
ALTER TABLE `Token`
  ADD PRIMARY KEY (`id`),
  ADD KEY `Token_userId_fkey` (`salesRepId`),
  ADD KEY `idx_token_value` (`token`(64)),
  ADD KEY `idx_token_cleanup` (`expiresAt`,`blacklisted`),
  ADD KEY `idx_token_lookup` (`salesRepId`,`tokenType`,`blacklisted`,`expiresAt`);

--
-- Indexes for table `UpliftSale`
--
ALTER TABLE `UpliftSale`
  ADD PRIMARY KEY (`id`),
  ADD KEY `UpliftSale_clientId_fkey` (`clientId`),
  ADD KEY `UpliftSale_userId_fkey` (`userId`);

--
-- Indexes for table `UpliftSaleItem`
--
ALTER TABLE `UpliftSaleItem`
  ADD PRIMARY KEY (`id`),
  ADD KEY `UpliftSaleItem_upliftSaleId_fkey` (`upliftSaleId`),
  ADD KEY `UpliftSaleItem_productId_fkey` (`productId`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `user_devices`
--
ALTER TABLE `user_devices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_user_device` (`user_id`,`device_id`),
  ADD KEY `idx_device_id` (`device_id`),
  ADD KEY `idx_user_active` (`user_id`,`is_active`),
  ADD KEY `idx_ip_address` (`ip_address`);

--
-- Indexes for table `versions`
--
ALTER TABLE `versions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `VisibilityReport`
--
ALTER TABLE `VisibilityReport`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `VisibilityReport_reportId_key` (`reportId`),
  ADD KEY `VisibilityReport_userId_idx` (`userId`),
  ADD KEY `VisibilityReport_clientId_idx` (`clientId`),
  ADD KEY `VisibilityReport_reportId_idx` (`reportId`);

--
-- Indexes for table `warning_letters`
--
ALTER TABLE `warning_letters`
  ADD PRIMARY KEY (`id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `account_category`
--
ALTER TABLE `account_category`
  MODIFY `id` int(3) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `account_ledger`
--
ALTER TABLE `account_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=51;

--
-- AUTO_INCREMENT for table `account_types`
--
ALTER TABLE `account_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `allowed_ips`
--
ALTER TABLE `allowed_ips`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `assets`
--
ALTER TABLE `assets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `asset_assignments`
--
ALTER TABLE `asset_assignments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `asset_types`
--
ALTER TABLE `asset_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance`
--
ALTER TABLE `attendance`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `Category`
--
ALTER TABLE `Category`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `CategoryPriceOption`
--
ALTER TABLE `CategoryPriceOption`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `chart_of_accounts`
--
ALTER TABLE `chart_of_accounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=145;

--
-- AUTO_INCREMENT for table `chart_of_accounts1`
--
ALTER TABLE `chart_of_accounts1`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `chat_messages`
--
ALTER TABLE `chat_messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=60;

--
-- AUTO_INCREMENT for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `chat_room_members`
--
ALTER TABLE `chat_room_members`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT for table `ClientAssignment`
--
ALTER TABLE `ClientAssignment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `Clients`
--
ALTER TABLE `Clients`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10804;

--
-- AUTO_INCREMENT for table `client_ledger`
--
ALTER TABLE `client_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=83;

--
-- AUTO_INCREMENT for table `client_payments`
--
ALTER TABLE `client_payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `Country`
--
ALTER TABLE `Country`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `credit_notes`
--
ALTER TABLE `credit_notes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `credit_note_items`
--
ALTER TABLE `credit_note_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `customers`
--
ALTER TABLE `customers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `distributors_targets`
--
ALTER TABLE `distributors_targets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `documents`
--
ALTER TABLE `documents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `employee_contracts`
--
ALTER TABLE `employee_contracts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `employee_documents`
--
ALTER TABLE `employee_documents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `employee_warnings`
--
ALTER TABLE `employee_warnings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `faulty_products_items`
--
ALTER TABLE `faulty_products_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `faulty_products_reports`
--
ALTER TABLE `faulty_products_reports`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `FeedbackReport`
--
ALTER TABLE `FeedbackReport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3703;

--
-- AUTO_INCREMENT for table `hr_calendar_tasks`
--
ALTER TABLE `hr_calendar_tasks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `inventory_receipts`
--
ALTER TABLE `inventory_receipts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `inventory_transactions`
--
ALTER TABLE `inventory_transactions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=91;

--
-- AUTO_INCREMENT for table `inventory_transfers`
--
ALTER TABLE `inventory_transfers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `journal_entries`
--
ALTER TABLE `journal_entries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=132;

--
-- AUTO_INCREMENT for table `journal_entry_lines`
--
ALTER TABLE `journal_entry_lines`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=326;

--
-- AUTO_INCREMENT for table `JourneyPlan`
--
ALTER TABLE `JourneyPlan`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8092;

--
-- AUTO_INCREMENT for table `key_account_targets`
--
ALTER TABLE `key_account_targets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `leaves`
--
ALTER TABLE `leaves`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=65;

--
-- AUTO_INCREMENT for table `leave_balances`
--
ALTER TABLE `leave_balances`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `leave_requests`
--
ALTER TABLE `leave_requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `leave_types`
--
ALTER TABLE `leave_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `LoginHistory`
--
ALTER TABLE `LoginHistory`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2584;

--
-- AUTO_INCREMENT for table `managers`
--
ALTER TABLE `managers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `merchandise`
--
ALTER TABLE `merchandise`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `merchandise_assignments`
--
ALTER TABLE `merchandise_assignments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `merchandise_categories`
--
ALTER TABLE `merchandise_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `merchandise_ledger`
--
ALTER TABLE `merchandise_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `merchandise_stock`
--
ALTER TABLE `merchandise_stock`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `my_assets`
--
ALTER TABLE `my_assets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `my_order`
--
ALTER TABLE `my_order`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT for table `my_order_items`
--
ALTER TABLE `my_order_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `my_receipts`
--
ALTER TABLE `my_receipts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `non_supplies`
--
ALTER TABLE `non_supplies`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `NoticeBoard`
--
ALTER TABLE `NoticeBoard`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `notices`
--
ALTER TABLE `notices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `outlet_categories`
--
ALTER TABLE `outlet_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `out_of_office_requests`
--
ALTER TABLE `out_of_office_requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `payroll_history`
--
ALTER TABLE `payroll_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `Product`
--
ALTER TABLE `Product`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `ProductExpiryReport`
--
ALTER TABLE `ProductExpiryReport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `ProductReport`
--
ALTER TABLE `ProductReport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=64932;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=123;

--
-- AUTO_INCREMENT for table `purchase_orders`
--
ALTER TABLE `purchase_orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `purchase_order_items`
--
ALTER TABLE `purchase_order_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `receipts`
--
ALTER TABLE `receipts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `Regions`
--
ALTER TABLE `Regions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `retail_targets`
--
ALTER TABLE `retail_targets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `Riders`
--
ALTER TABLE `Riders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `riders_company`
--
ALTER TABLE `riders_company`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `routes`
--
ALTER TABLE `routes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=72;

--
-- AUTO_INCREMENT for table `salesclient_payment`
--
ALTER TABLE `salesclient_payment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `SalesRep`
--
ALTER TABLE `SalesRep`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=236;

--
-- AUTO_INCREMENT for table `sales_orders`
--
ALTER TABLE `sales_orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=99;

--
-- AUTO_INCREMENT for table `sales_order_items`
--
ALTER TABLE `sales_order_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=135;

--
-- AUTO_INCREMENT for table `sales_rep_managers`
--
ALTER TABLE `sales_rep_managers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `sales_rep_manager_assignments`
--
ALTER TABLE `sales_rep_manager_assignments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `ShowOfShelfReport`
--
ALTER TABLE `ShowOfShelfReport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `staff`
--
ALTER TABLE `staff`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `staff_tasks`
--
ALTER TABLE `staff_tasks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stock_takes`
--
ALTER TABLE `stock_takes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `stock_take_items`
--
ALTER TABLE `stock_take_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38;

--
-- AUTO_INCREMENT for table `stores`
--
ALTER TABLE `stores`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `store_inventory`
--
ALTER TABLE `store_inventory`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT for table `suppliers`
--
ALTER TABLE `suppliers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `supplier_ledger`
--
ALTER TABLE `supplier_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `targets`
--
ALTER TABLE `targets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tasks`
--
ALTER TABLE `tasks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `termination_letters`
--
ALTER TABLE `termination_letters`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `Token`
--
ALTER TABLE `Token`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=47;

--
-- AUTO_INCREMENT for table `UpliftSale`
--
ALTER TABLE `UpliftSale`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `UpliftSaleItem`
--
ALTER TABLE `UpliftSaleItem`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `user_devices`
--
ALTER TABLE `user_devices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `versions`
--
ALTER TABLE `versions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `VisibilityReport`
--
ALTER TABLE `VisibilityReport`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4448;

--
-- AUTO_INCREMENT for table `warning_letters`
--
ALTER TABLE `warning_letters`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `asset_assignments`
--
ALTER TABLE `asset_assignments`
  ADD CONSTRAINT `asset_assignments_ibfk_1` FOREIGN KEY (`asset_id`) REFERENCES `my_assets` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `asset_assignments_ibfk_2` FOREIGN KEY (`staff_id`) REFERENCES `staff` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `asset_assignments_ibfk_3` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `credit_notes`
--
ALTER TABLE `credit_notes`
  ADD CONSTRAINT `credit_notes_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `Clients` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `credit_notes_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `credit_note_items`
--
ALTER TABLE `credit_note_items`
  ADD CONSTRAINT `credit_note_items_ibfk_1` FOREIGN KEY (`credit_note_id`) REFERENCES `credit_notes` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `credit_note_items_ibfk_2` FOREIGN KEY (`invoice_id`) REFERENCES `sales_orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `credit_note_items_ibfk_3` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `LoginHistory`
--
ALTER TABLE `LoginHistory`
  ADD CONSTRAINT `LoginHistory_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `merchandise`
--
ALTER TABLE `merchandise`
  ADD CONSTRAINT `merchandise_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `merchandise_categories` (`id`);

--
-- Constraints for table `merchandise_assignments`
--
ALTER TABLE `merchandise_assignments`
  ADD CONSTRAINT `merchandise_assignments_ibfk_1` FOREIGN KEY (`merchandise_id`) REFERENCES `merchandise` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `merchandise_assignments_ibfk_2` FOREIGN KEY (`staff_id`) REFERENCES `staff` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `merchandise_ledger`
--
ALTER TABLE `merchandise_ledger`
  ADD CONSTRAINT `merchandise_ledger_ibfk_1` FOREIGN KEY (`merchandise_id`) REFERENCES `merchandise` (`id`),
  ADD CONSTRAINT `merchandise_ledger_ibfk_2` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`);

--
-- Constraints for table `merchandise_stock`
--
ALTER TABLE `merchandise_stock`
  ADD CONSTRAINT `merchandise_stock_ibfk_1` FOREIGN KEY (`merchandise_id`) REFERENCES `merchandise` (`id`),
  ADD CONSTRAINT `merchandise_stock_ibfk_2` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`);

--
-- Constraints for table `ProductExpiryReport`
--
ALTER TABLE `ProductExpiryReport`
  ADD CONSTRAINT `ProductExpiryReport_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ProductExpiryReport_journeyPlanId_fkey` FOREIGN KEY (`journeyPlanId`) REFERENCES `JourneyPlan` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ProductExpiryReport_productId_fkey` FOREIGN KEY (`productId`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `ProductExpiryReport_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `ShowOfShelfReport`
--
ALTER TABLE `ShowOfShelfReport`
  ADD CONSTRAINT `ShowOfShelfReport_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ShowOfShelfReport_journeyPlanId_fkey` FOREIGN KEY (`journeyPlanId`) REFERENCES `JourneyPlan` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ShowOfShelfReport_productId_fkey` FOREIGN KEY (`productId`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `ShowOfShelfReport_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `staff_tasks`
--
ALTER TABLE `staff_tasks`
  ADD CONSTRAINT `fk_staff_tasks_assigned_by` FOREIGN KEY (`assigned_by_id`) REFERENCES `staff` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_staff_tasks_staff` FOREIGN KEY (`staff_id`) REFERENCES `staff` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
