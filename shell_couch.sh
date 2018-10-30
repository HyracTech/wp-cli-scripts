#! /bin/bash


function is_running(){
  curl http://127.0.0.1:5984/
}

function list_dbs(){
  curl -X GET http://127.0.0.1:5984/_all_dbs
}

function create_db(){
  local db="$1"
  curl -X PUT http://127.0.0.1:5984/"$db"
}

function delete_db(){
  local db="$1"
  curl -X DELETE http://127.0.0.1:5984/"$db"
}


function replicate_dbs(){
  local source_db="$1"
  local target_db="$2"

  echo "Source DB: $source_db ==> target DB: $target_db"

  curl -H 'Content-Type: application/json' -X POST http://localhost:5984/_replicate -d ' {"source": "http://localhost:5984/$source_db", "target": "http://localhost:5984$
}

#In case you want just one-off replication, you would need to change continuous parameter to false or just simply omit it.
#If you want to see couchDB logs, you can find it in /var/log/couchdb/couch.log directory.
#You would need sudo or root privileges to access it, and if you want to watch logs interactively, this command will do it
#sudo tail -f /var/log/couchdb/couch.log


# This function inserts a document into a couchdb database using 'put' method. You have to specify the id of the document

function insert_doc(){
  local id="$1"
  local db="$2"

  curl -X PUT http://127.0.0.1:5984/"$db"/"$id" \ 
       -d'{" Name " : " Raju " , " age " :" 23 " , " Designation " : " Designer "}'

}

# This function inserts a document into a couchdb database using 'post' method. The ID is automatically generated

function post_doc(){
  local db="$1"

  curl -H 'Content-Type: application/json' -X POST http://127.0.0.1:5984/"$db" -d'{" Name " : " Raju " , " age " :" 23 " , " Designation " : " Designer "}'

}

#Inserting a document from a json file
function insert_from_file(){
  local id="$1"
  local db="$2"

  wp post get "$id" --format=json > temp_file.json --allow-root


  curl -X PUT -H "Content-type: application/json" -d@temp_file.json http://127.0.0.1:5984/"$db"/"$id"
  #You can then delete the temp file
  #rm temp_file.json
}

#Convert all available worpress posts to couchdb documents
function wp_posts_to_couch(){

  #making a text file of post ids using wpcli
  wp post list --field=ID --allow-root > id.txt

  #Make an array of ids from the text file created above
  array=(`cat id.txt`)
  echo " Length of Array: ${#array[@]}"
  
  for t in "${array[@]}"
  do
    insert_from_file $t "database_name"
    #echo $t
  done
  echo "Finished copying all the WP posts to couchdb documents!"

} 


#View a ducument from a database. you have to specify the id of the doc and the db
function view_doc(){ 
  local id="$1"
  local db="$2"

  curl -X GET http://127.0.0.1:5984/"$db"/"$id"

}

#Update a document in couchdb
#This function still needs work. Need to find a way to get the _revision value. Could try using awk, and sed in bash
function update_doc(){
  local id="$1"
  local db="$2"
  
  
  #get the _revision value .I love the jq comandline JSON  processor be sure to install it and use it to get the rev value
  local rev_id="$(curl -X GET http://127.0.0.1:5984/"$db"/"$id" | jq '._rev')"
  #When Updating make sure you include all the fields that were originally there and your updated copy then update
  #Otherwise the new document will only have your one updated field
  #curl -X PUT http://127.0.0.1:5984/database_name/document_id/ -d '{ "field" : "value", "_rev" : '$rev_id' }'

  curl -X PUT http://127.0.0.1:5984/"$db"/"$id" -d ' { " age " : " 24 " , " _rev " : " 1-1c2fae390fa5475d9b809301bbf3f25e " } '
  #In return JSON contains the success message, the ID of the document being updated, and the new revision information. 
  #If you want to update the new version of the document, you have to quote this latest revision number.
}

#You can attach files to CouchDB just like email. The file contains metadata like name and includes its MIME type, and the number of bytes the attachment contains.
#To attach files to a document you have to send PUT request to the server. Following is the syntax to attach files to the document −
#First you have to get the document id and _rev

function attach_doc(){

  #curl -vX PUT http://127.0.0.1:5984/db_name/doc_id/filename?rev=doc_rev_id --data-binary @filename -H "Content-Type:type of the content"
  #--data-binary@ - This option tells cURL to read a file’s contents into the HTTP request body.

  #curl -vX PUT http://127.0.0.1:5984/my_database/001/boy.jpg?rev=1-967a00dff5e02add41819138abb3284d --data-binary @boy.jpg -H "ContentType:#image/jpg"
}



# Making an array from a contents of a text file
#array=(`cat id.txt`)

#making a text file of post ids using wpcli
#wp post list --field=ID --allow-root > id.txt

#You can check array index content by.
#echo "${array[3]}"

#Printing contents of the array
echo " Length of Array: ${#array[@]}"
echo  "----------------/n"

#for t in "${array[@]}"
#do
#echo $t
#done
#echo "Read file content!"


####TODOS###
#Error checking and handling in the functions
#Finish working on Update function
# Use python to make Json files from bash commands then use curl to put the different info got into couchdb from a different bash script
#check date modified in couchdb document and match with the one in wordpress post if different then update the couchdb document
#Writing views to couchdb using curl
#Examples on this site https://www.lullabot.com/articles/a-recipe-for-creating-couchdb-views




