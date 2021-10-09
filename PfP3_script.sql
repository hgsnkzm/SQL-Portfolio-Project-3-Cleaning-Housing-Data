
--  < Cleaning Data in SQL Queries. >

SELECT *
FROM nashville_housing_dataset
;


---------------------

-- 1. Standerdize Data Format.

SELECT SaleDate, substr(SaleDate, 1, 4) ||'-' ||  substr(SaleDate, 6, 2) || '-' || substr(SaleDate, 9, 2) 
FROM nashville_housing_dataset
;

UPDATE nashville_housing_dataset
SET SaleDate = substr(SaleDate, 1, 4) ||'-' ||  substr(SaleDate, 6, 2) || '-' || substr(SaleDate, 9, 2) 


---------------------

-- 2. Populate Property Address data.
-- Property Address columns contains some NULL values, but we can know what those NULL addresses are from other data which have same ParcelID. 
-- We're going to replace NULL values to proper address using self join.

SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, IFNULL(a.PropertyAddress, b.PropertyAddress)
FROM nashville_housing_dataset a
JOIN nashville_housing_dataset b on a.ParcelID = b.ParcelID AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress is NULL

UPDATE nashville_housing_dataset
SET PropertyAddress = (
		SELECT IFNULL(a.PropertyAddress, b.PropertyAddress)
		FROM nashville_housing_dataset a
		JOIN nashville_housing_dataset b on a.ParcelID = b.ParcelID AND a.UniqueID <> b.UniqueID	
		WHERE a.PropertyAddress is NULL
		)
WHERE PropertyAddress is NULL
;


---------------------

-- 3. Breaking out Address into Indivisual Columns (Address, City, State).
-- split the property address into address and city using substring.

SELECT substr(PropertyAddress, 1, instr(PropertyAddress, ',') - 1) as Address
, substr(PropertyAddress, instr(PropertyAddress, ',') +1, length(PropertyAddress)) as City
FROM nashville_housing_dataset
;

-- Add two new columns to the table using ALTER TABLE and UPDATE.

ALTER TABLE nashville_housing_dataset
ADD PropertySplitAddress TEXT;

UPDATE nashville_housing_dataset
SET PropertySplitAddress = substr(PropertyAddress, 1, instr(PropertyAddress, ',') - 1)

ALTER TABLE nashville_housing_dataset
ADD PropertySplitCity TEXT;

UPDATE nashville_housing_dataset
SET PropertySplitCity = substr(PropertyAddress, instr(PropertyAddress, ',') +1, length(PropertyAddress))

SELECT *
FROM nashville_housing_dataset

-- Also split owner address. Use CTE this time.

WITH SplitOwnerAddress (Address, subadd)
AS(
	SELECT substr(OwnerAddress, 1, instr(OwnerAddress, ',') -1) as Address
					, substr(OwnerAddress, instr(OwnerAddress, ',') +1,  length(OwnerAddress)) as subadd
	FROM nashville_housing_dataset
)
SELECT *, substr(subadd, 1, instr(subadd, ',') -1) as City
, substr(subadd, instr(subadd, ',') +1, length(subadd)) as State
FROM SplitOwnerAddress
;

ALTER TABLE nashville_housing_dataset
ADD OwnerSplitAddress TEXT;

UPDATE nashville_housing_dataset
SET OwnerSplitAddress = substr(OwnerAddress, 1, instr(OwnerAddress, ',') -1)

ALTER TABLE nashville_housing_dataset
ADD subadd TEXT;

UPDATE nashville_housing_dataset
SET subadd = substr(OwnerAddress, instr(OwnerAddress, ',') +1,  length(OwnerAddress))

ALTER TABLE nashville_housing_dataset
ADD OwnerSplitCity TEXT;

UPDATE nashville_housing_dataset
SET OwnerSplitCity = substr(subadd, 1, instr(subadd, ',') -1)

ALTER TABLE nashville_housing_dataset
ADD OwnerSplitState TEXT;

UPDATE nashville_housing_dataset
SET OwnerSplitState = substr(subadd, instr(subadd, ',') +1, length(subadd))


SELECT *
FROM nashville_housing_dataset
;


---------------------

-- 4. Change Y and N to Yes and No in "Sold as Vacant" field.

SELECT DISTINCT(SoldAsVacant)
FROM nashville_housing_dataset
;

-- There are 4 types of values in SoldAsVacant column. 
-- Change Y to Yes, N to No by using CASE statement.

SELECT SoldAsVacant
, CASE SoldAsVacant 
  WHEN 'Y' THEN 'Yes'
  WHEN 'N' THEN 'No'
  ELSE SoldAsVacant
  END 
FROM nashville_housing_dataset
;

UPDATE nashville_housing_dataset
SET SoldAsVacant = (CASE SoldAsVacant 
  WHEN 'Y' THEN 'Yes'
  WHEN 'N' THEN 'No'
  ELSE SoldAsVacant
  END
)


---------------------

-- 5. Remove Duplicates.
-- Even if the unique ID is different, there may be some rows which contains completely same data. Identify those rows by using ROWID and delete them.
-- If random multiple rows share the same ParcelID, PropertyAddress, SalePrice, SaleDate and LegalReference, we could say those rows are duplicated rows.

WITH DuplicatedRows
AS (
	SELECT *, row_number() OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY UniqueID) as row_num
	FROM nashville_housing_dataset
)
SELECT *
FROM DuplicatedRows
WHERE row_num > 1
;

-- Datasett contains 103 duplicate rows.

DELETE
FROM nashville_housing_dataset
WHERE ROWID not in (
	SELECT min(ROWID)
	FROM nashville_housing_dataset
	GROUP BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
)


---------------------

-- 6. Delete Unused Columns.
-- SQLite dosen't support DROP COLUMN in version 3.12.2
-- So we're going to create temp table and backup needed data to it, then create new table and copy those needed data to it from temp table.

CREATE TEMPORARY TABLE nashville_housing_dataset_backup (
UniqueID
, ParcelID
, LandUse
, PropertySplitAddress
, PropertySplitCity
, SaleDate, SalePrice
, LegalReference
, SoldAsVacant
, OwnerName
, OwnerSplitAddress
, OwnerSplitCity
, OwnerSplitState
, Acreage
, LandValue
, BuildingValue
, TotalValue
, YearBuilt
, Bedrooms
, FullBath
, HalfBath
);

INSERT INTO nashville_housing_dataset_backup SELECT  
UniqueID
, ParcelID
, LandUse
, PropertySplitAddress
, PropertySplitCity
, SaleDate, SalePrice
, LegalReference
, SoldAsVacant
, OwnerName
, OwnerSplitAddress
, OwnerSplitCity
, OwnerSplitState
, Acreage
, LandValue
, BuildingValue
, TotalValue
, YearBuilt
, Bedrooms
, FullBath
, HalfBath
 FROM nashville_housing_dataset
;

CREATE TABLE nashville_housing_dataset_ver2(
UniqueID
, ParcelID
, LandUse
, PropertySplitAddress
, PropertySplitCity
, SaleDate, SalePrice
, LegalReference
, SoldAsVacant
, OwnerName
, OwnerSplitAddress
, OwnerSplitCity
, OwnerSplitState
, Acreage
, LandValue
, BuildingValue
, TotalValue
, YearBuilt
, Bedrooms
, FullBath
, HalfBath
);

INSERT INTO nashville_housing_dataset_ver2 SELECT  
UniqueID
, ParcelID
, LandUse
, PropertySplitAddress
, PropertySplitCity
, SaleDate, SalePrice
, LegalReference
, SoldAsVacant
, OwnerName
, OwnerSplitAddress
, OwnerSplitCity
, OwnerSplitState
, Acreage
, LandValue
, BuildingValue
, TotalValue
, YearBuilt
, Bedrooms
, FullBath
, HalfBath
 FROM nashville_housing_dataset_backup
;

SELECT *
FROM nashville_housing_dataset_ver2
;

