# Exploring Iceberg Tables

In this section, we will create Iceberg tables and explore their structure in the underlying data source. We will also take a look at the hidden tables that Presto provides for Iceberg that give information on the table metadata. We'll also use some of Iceberg's key features - schema evolution and time travel - from Presto to get an idea of how they work.

This section is comprised of the following steps:

- [Exploring Iceberg Tables](#exploring-iceberg-tables)
  - [1. Creating a schema](#1-creating-a-schema)
  - [2. Creating an Iceberg table](#2-creating-an-iceberg-table)
  - [3. Iceberg schema evolution](#3-iceberg-schema-evolution)
  - [4. Iceberg time travel](#4-iceberg-time-travel)

## 1. Creating a schema

First, let's learn how to run the Presto CLI to connect to the coordinator. There are several ways to do that:

1. Download the executable jar from the official repository and run the jar file with a proper JVM. You can see details in this [documentation](http://prestodb.io/docs/current/installation/cli.html#install-the-presto-cli).
2. Use the `presto-cli` that comes with the `prestodb/presto` Docker image

For this lab, since we run everything on Docker containers, we are going to use the second approach. You can run the `presto-cli` inside the coordinator container with the below command:

```sh
$ docker exec -it presto-coordinator presto-cli
presto>
```

!!! note
    Since the `presto-cli` is executed inside the `coordinator` and `localhost:8080` is the default server, there is no need to specify the `--server` argument.

After you run the command, the prompt should change from the shell prompt `$` to the `presto>` CLI prompt. Run the SQL statement `show catalogs` to see a list of currently configured catalogs:

```sh
presto> show catalogs;
 Catalog 
---------
 hive    
 iceberg 
 jmx     
 memory  
 system  
 tpcds   
 tpch    
(7 rows)

Query 20231122_230131_00021_79xda, FINISHED, 1 node
Splits: 19 total, 19 done (100.00%)
[Latency: client-side: 173ms, server-side: 163ms] [0 rows, 0B] [0 rows/s, 0B/s]
```

These are the catalogs that we specified when launching the coordinator container by using the configurations from the `presto/catalog` directory. The `hive` and `iceberg` catalogs here are expected, but here is a short description of the rest:

- [jmx](http://prestodb.io/docs/current/connector/jmx.html): The JMX connector provides the ability to query JMX
  information from all nodes in a Presto cluster.
- [memory](http://prestodb.io/docs/current/connector/memory.html): The Memory connector stores all data and metadata
  in RAM on workers and both are discarded when Presto restarts.
- [system](http://prestodb.io/docs/current/connector/system.html): The System connector provides information and
  metrics about the currently running Presto cluster.
- [tpcds](http://prestodb.io/docs/current/connector/tpcds.html): The TPCDS connector provides a set of schemas
  to support the TPC Benchmark™ DS (TPC-DS)
- [tpch](http://prestodb.io/docs/current/connector/tpch.html): The TPCH connector provides a set of schemas to
  support the TPC Benchmark™ H (TPC-H).

Now, let's create a schema. A schema is a logical way to organize tables within a catalog. We'll create a schema called "minio" within our "iceberg" catalog. We also want to specify that the tables within this schema are all located in our s3 storage, and more specifically, in the `test-bucket` bucket that we created previously.

```sh
presto> CREATE SCHEMA iceberg.minio with (location = 's3a://test-bucket/');
CREATE SCHEMA
```

We'll be working almost exclusively with the "iceberg" catalog and "minio" schema, so we can employ a `USE` statement to indicate that all the queries we run will be against tables in this catalog/schema combination unless specificed. Otherwise, we would have to use the fully-qualified table name for every statement (i.e., `iceberg.minio.<table_name>`).

```sh
presto> USE iceberg.minio;
USE
presto:minio>
```

You'll notice that the prompt has changed to also include the schema we're working in. Now we're ready to create a table!

## 2. Creating an Iceberg table

When creating a new table, we specify the name and the table schema. A table schema is different than the schema we've been referring to up until now. The table schema defines the column names and types. Let's create a table to represent the books that a (very small) library has in their inventory.

```sh
presto:minio> CREATE TABLE books (id bigint, title varchar, author varchar) WITH (location = 's3a://test-bucket/minio/books');
CREATE TABLE
```

We now have the table structure, but no data. Let's look into this a little bit. Pull up your MinIO UI and navigate to the `test-bucket/minio/books` directory. Notice that the `minio` and `books` directories were created implicitly with the location property that we passed to `CREATE TABLE`. There should be a single folder at this location called `metadata`. If you go into this directory, you'll see a single metadata file with the extension `.metadata.json`, which stores the table schema information.

Let's add some data to this table:

```sh
presto:minio> INSERT INTO books VALUES (1, 'Pride and Prejudice', 'Jane Austen'), (2, 'To Kill a Mockingbird', 'Harper Lee'), (3, 'The Great Gatsby', 'F. Scott Fitzgerald');
INSERT: 3 rows

Query 20231123_021811_00005_79xda, FINISHED, 1 node
Splits: 35 total, 35 done (100.00%)
[Latency: client-side: 0:01, server-side: 0:01] [0 rows, 0B] [0 rows/s, 0B/s]
```

We can verify our data by running a `SELECT *` statement:

```sh
presto:minio> SELECT * FROM books;
 id |         title         |       author        
----+-----------------------+---------------------
  1 | Pride and Prejudice   | Jane Austen         
  2 | To Kill a Mockingbird | Harper Lee          
  3 | The Great Gatsby      | F. Scott Fitzgerald 
(3 rows)
```

If we go back to our MinIO UI now, we can see a new folder, `data` in the `test-bucket/minio/books` path. The `data` folder has a single `.parquet` data file inside. This structure of `data` and `metadata` folders is the default for Iceberg tables.

We can query some of the Iceberg metadata information from Presto. Let's look at the hidden "history" table from Presto. Note that the quotation marks are required here.

```sh
presto:minio> SELECT * FROM "books$history";
       made_current_at       |     snapshot_id     | parent_id | is_current_ancestor 
-----------------------------+---------------------+-----------+---------------------
 2023-11-23 02:18:12.411 UTC | 5661912010858659685 | NULL      | true                
(1 row)

Query 20231123_022725_00007_79xda, FINISHED, 1 node
Splits: 17 total, 17 done (100.00%)
[Latency: client-side: 0:01, server-side: 0:01] [1 rows, 17B] [1 rows/s, 20B/s]
```

This shows us that we have a snapshot that was created at the moment we inserted data. We can get more details about the snapshot with the below query:

```sh
presto:minio> SELECT * FROM "books$snapshots";
```

This gets us a little more information, such as the manifest list file that this snapshot refers to.

There are other hidden tables as well that you can interrogate. Here is a list of all hidden tables that Presto can provide:

- `$properties`: General properties of the given table
- `$history`: History of table state changes
- `$snapshots`: Details about the table snapshots
- `$manifests`: Details about the manifest lists of different table snapshots
- `$partitions`: Detailed partition information for the table
- `$files`: Overview of data files in the current snapshot of the table

## 3. Iceberg schema evolution

The Iceberg connector also supports in-place table evolution, aka schema evolution, such as adding, dropping, and renaming columns. This is one of Iceberg's key features. Let's try it. Let's say we want to add a column to indicate whether a book has been checked out. We'll run the following command to do so:

```sh
presto:minio> ALTER TABLE books ADD COLUMN checked_out boolean;
ADD COLUMN
```

At this point, a new `.metadata.json` file is created and can be viewed in the MinIO UI, but, once again, no updates to the other metadata files or the hidden tables take place until data is added. The library comes into the possession of a new book and it is immediately checked out. We can add data for that:

```sh
presto:minio> INSERT INTO books VALUES (4, 'One Hundred Years of Solitude', 'Gabriel Garcia Marquez', true);
INSERT: 1 row

Query 20231123_025430_00013_79xda, FINISHED, 1 node
Splits: 35 total, 35 done (100.00%)
[Latency: client-side: 0:01, server-side: 0:01] [0 rows, 0B] [0 rows/s, 0B/s]
```

At this point, a new snapshot is made current, which we can see by querying the hidden snapshot table:

```sh
presto:minio> SELECT * FROM "books$snapshots";
```

The output confirms that we now have a new snapshot, and a new manifest list file representing it.

## 4. Iceberg time travel

========== stop here if using `prestodb/presto:0.282` image ===========

Another popular feature of Iceberg is time travel, wherein we can query the table state from a given time or snapshot ID. It's also possible to rollback the state of a table to a previous snapshot using its ID. For the purposes of our example, let's say the person that checked out _One Hundred Days of Solitude_ enjoyed it so much that they bought it from the library, taking it out of the inventory. We want to roll the table state back to before we inserted the latest row. Let's first get our snapshot IDs.

```sh
presto:minio> SELECT snapshot_id, committed_at FROM "books$snapshots" ORDER BY committed_at;
     snapshot_id     |              committed_at               
---------------------+-----------------------------------------
 5837462824399906536 | 2023-11-27 18:15:36.759 America/Chicago 
 6203469669433850326 | 2023-11-27 18:17:49.206 America/Chicago 
(2 rows)
```

Let's verify that the table is in the expected state at our earliest snapshot ID:

```sh
presto:minio> SELECT * FROM books FOR VERSION AS OF 5837462824399906536;
 id |         title         |       author        | checked_out 
----+-----------------------+---------------------+-------------
  1 | Pride and Prejudice   | Jane Austen         | NULL        
  2 | To Kill a Mockingbird | Harper Lee          | NULL        
  3 | The Great Gatsby      | F. Scott Fitzgerald | NULL        
(3 rows)
```

We could also do the same thing using a timestamp or date. If you run this query, make sure you change the timestamp so that it's accurate for the time at which you're following along.

```sh
presto:minio> SELECT * FROM books FOR TIMESTAMP AS OF TIMESTAMP '2023-08-17 13:29:46.822 America/Los_Angeles';
 id |         title         |       author        | checked_out 
----+-----------------------+---------------------+-------------
  1 | Pride and Prejudice   | Jane Austen         | NULL        
  2 | To Kill a Mockingbird | Harper Lee          | NULL        
  3 | The Great Gatsby      | F. Scott Fitzgerald | NULL        
(3 rows)
```

Now that we've verified the table state that we want to roll back to, we can call a procedure on the "iceberg" catalog's built-in `system` schema to do so:

```sh
presto:minio> CALL iceberg.system.rollback_to_snapshot('minio', 'books', 5837462824399906536);
CALL
```

Let's verify that the table is back to how it was before:

```sh
presto:minio> SELECT * FROM books;
 id |         title         |       author        | checked_out 
----+-----------------------+---------------------+-------------
  1 | Pride and Prejudice   | Jane Austen         | NULL        
  2 | To Kill a Mockingbird | Harper Lee          | NULL        
  3 | The Great Gatsby      | F. Scott Fitzgerald | NULL        
(3 rows)
```

Notice that the table still includes the `checked_out` column. This is to be expected because the snapshot only changes when data files are written to. Removing the column would be another schema evolution operation that only changes the `.metadata.json` file and not the snapshot itself.

You just explored some of Iceberg's key features using Presto! Presto's Iceberg connector has more features than those we've gone over today, such as partitioning and partition column transforms, as well as additional features that are soon-to-come!
