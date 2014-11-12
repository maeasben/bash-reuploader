--
-- upfile table
-- Contains all links and last seen time
-- * fid : unique identifier (integer autoincrement)
-- * source : original link (unique)
-- * file : local filename (the downloaded file)
-- * seen : last seen time (epoch)
-- * link : the actual working link
-- * tries : number of download tries
--

CREATE TABLE IF NOT EXISTS upfile (
	fid integer primary key autoincrement,
	source text unique,
	file text,
	seen date,
	link text,
	tries integer
);

