CREATE DATABASE presto_to_mysql;
show databases;
use presto_to_mysql;
show tables;
create table author(id bigint, author varchar(255));
insert into author values(1, "Rowlings");
insert into author values(2, "Holly Black");
insert into author values(3, "Stephen King");
insert into author values(4, "Rick Riorden");
