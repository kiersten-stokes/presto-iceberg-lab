use presto_to_mongodb;
db.createCollection("book")
db.book.insertOne({"id":1, "book_name":"harry potter" })
db.book.insertOne({"id":2, "book_name":"The forgotten" })
db.book.insertOne({"id":3, "book_name":"The Alchemist" })
db.book.insertOne({"id":4, "book_name":"Engines of Liberty" })