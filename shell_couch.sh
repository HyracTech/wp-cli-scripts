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
  rm temp_file.json
}

#Convert all available worpress posts to couchdb documents. This should only be run once in a new couchdb database
#For posting additional wp posts to couch either use new_wp_posts_to_couch function or add each post individually
#In future i could combine the two functions and check if we have a new couchdb database or not

function wp_all_posts_to_couch(){
  local db="$1"
  
  #making a text file of post ids using wpcli
  wp post list --field=ID --allow-root > wp_post_ids.txt

  #Make an array of ids from the text file created above
  array=(`cat wp_post_ids.txt`)
  echo " Length of Array: ${#array[@]}"
  
  for t in "${array[@]}"
  do
    insert_from_file $t "$db"
    #echo $t
  done
  echo "Finished copying all the WP posts to couchdb documents!"

} 


#This will look if there are posts that are in WP and not in Couchdb and load them if there is.
function new_wp_posts_to_couch(){
  local db="$1"

  #If number of couch documents in a database is 0 then its a new database
  local number_of_couch_documents="$(curl -X GET localhost:5984/"$db" | jq '.doc_count')"

  if [ "$number_of_couch_documents" -eq "0" ]
  then
        echo "This is a new database. It has $number_of_couch_documents documents."
        #call the wp_all_posts_to_couch function
        wp_all_posts_to_couch "$db"
  elif [ "$number_of_couch_documents" -gt "0" ]
  then
        echo "This is an existing db with $number_of_couch_documents documents just check for wp posts that are not in couchdb and load them" 
        #check if  an existing wp_post_ids.txt file exist
        if [ -f wp_post_ids.txt ]
        then
          echo "the id text file exists"

          #create a temporary file with the current ids from wordpress
          wp post list --field=ID --allow-root > new_wp_post_ids.txt

          new_ids_array=(`cat new_wp_post_ids.txt`)
          old_ids_array=(`cat wp_post_ids.txt`)

          diff_in_arrays=()
          for i in "${new_ids_array[@]}"; do
              skip=
              for j in "${old_ids_array[@]}"; do
                  [[ $i == $j ]] && { skip=1; break; }
              done
              [[ -n $skip ]] || diff_in_arrays+=("$i")
          done

          echo " Number of new documents in WP to be added to couchdb is: ${#diff_in_arrays[@]}"
            if [ "${#diff_in_arrays[@]}" -ge "1" ]
            then
                for t in "${diff_in_arrays[@]}"
                do
                  insert_from_file $t "$db"
                  #echo $t
                done
                echo "Finished copying all the WP posts to couchdb documents!"

            else
                echo "All your wp posts are already in couchdb so you good."
            fi
          #Remove the old wp_post_ids.txt and replace it with the current ids and keep the name
          rm wp_post_ids.txt
          mv new_wp_post_ids.txt  wp_post_ids.txt
        else
          echo "The wp_post_ids.txt does not exist THATS A RED FLAG CHECK THE CODE ABOVE THAT CALLS wp_all_posts_to_couch function"
        fi
  else
        echo "This is not a new database. It has $number_of_couch_documents documents."
        echo "If you get a 'null' double check the name of your database and make sure it exists"
  fi

}



#This function checks for any posts modified in wp then updates the couchdb  equivalent document
function sync_wp_couch_posts(){
  local db="$1"
  #call new_wp_posts_to_couch function first to make sure all wp posts are duplicated in the couchdb database
  new_wp_posts_to_couch "$db"
  
  #check if  an existing wp_post_ids.txt file exist
  if [ -f wp_post_ids.txt ]
  then
      
        #Make an array of ids from the text file created above
        local array=(`cat wp_post_ids.txt`)
        echo " Total number of posts is: ${#array[@]}"

        for t in "${array[@]}"
        do
          #echo $t
           local wp_post_modified="$(wp post get $t --field=post_modified --allow-root)"
           local couch_post_modified="$(curl -X GET http://127.0.0.1:5984/"$db"/"$t" | jq -r '.post_modified')"

           local wp_post_modified_int=$(date -d "$wp_post_modified" +"%Y%m%d%H%M%S")
           local couch_post_modified_int=$(date -d "$couch_post_modified" +"%Y%m%d%H%M%S")

           if [ $wp_post_modified_int -gt $couch_post_modified_int ]; 
           then
             echo "Updating document ID: $t  !!!!!!!!!!";
             #Update_doc function updates the couchdb document, its args are id and db, we pass $t for the id
             update_doc "$t" "$db"
           fi

            echo "wp post ID$t : $wp_post_modified_int"
            echo "couchdb post ID$t : $couch_post_modified_int"

        done
  
  fi #closing for if [ -f wp_post_ids.txt ]
  
}



#View a ducument from a database. you have to specify the id of the doc and the db
function view_doc(){ 
  local id="$1"
  local db="$2"

  curl -X GET http://127.0.0.1:5984/"$db"/"$id"

}

#Update a document in couchdb
function update_doc(){
  local id="$1"
  local db="$2"
  
  #make a json file of the wordpress post to be updated
  wp post get "$id" --format=json > temp_file.json --allow-root

  #get the _revision value .I love the jq comandline JSON  processor be sure to install it and use it to get the rev value
  local rev_id="$(curl -X GET http://127.0.0.1:5984/"$db"/"$id" | jq -r '._rev')"
  #echo "$rev_id"
  
  #using jq add the _rev value of the couchdb document to be updated to the wp json post and output to a new file 
  cat temp_file.json | jq --arg revision_id $rev_id '. + {_rev: $revision_id}' > temp_file_with_rev.json
  
  #Update the couchdb document with the modified post from wordpress
  curl -X PUT -H "Content-type: application/json" http://127.0.0.1:5984/"$db"/"$id" -d@temp_file_with_rev.json

  #You can then delete the temp files
  rm temp_file.json temp_file_with_rev.json
  

  #When Updating make sure you include all the fields that were originally there and your updated copy then update
  #Otherwise the new document will only have your one updated field
  #curl -X PUT http://127.0.0.1:5984/database_name/document_id/ -d '{ "field" : "value", "_rev" : '$rev_id' }'
  #In return JSON contains the success message, the ID of the document being updated, and the new revision information. 
  #If you want to update the new version of the document, you have to quote this latest revision number.
}

#You can attach files to CouchDB just like email. The file contains metadata like name and includes its MIME type, and the number of bytes the attachment contains.
#To attach files to a document you have to send PUT request to the server. Following is the syntax to attach files to the document −
#First you have to get the document id and _rev

function attach_doc(){

  local id="$1"
  local db="$2"
  local rev_id="$(curl -X GET http://127.0.0.1:5984/"$db"/"$id" | jq -r '._rev')"  #use jq library to process json
  #echo "$rev_id"

  #curl -vX PUT http://127.0.0.1:5984/db_name/doc_id/filename?rev=doc_rev_id --data-binary @filename -H "Content-Type:type of the content"
  #--data-binary@ - This option tells cURL to read a file’s contents into the HTTP request body.

  curl -vX PUT http://127.0.0.1:5984/"$db"/"$id"/en-gcf2015.png?rev="$rev_id" --data-binary @en-gcf2015.png -H "ContentType:#image/png"
}


#This function exports the current wp database, makes a new couchdb document and adds the exported sql file as an attachment
function export_wp_db(){

  local db="$1"

  #Get the date
  local DATE=`date '+%Y-%m-%d %H:%M:%S'` #gives date in 2018-10-31 11:30:34 format 

  local id="$(date -d "$DATE" +"%Y%m%d%H%M%S")"  #gives date in 20181031113155 format

  #First create a couchdb document with backup date as the id, then the attachment
  curl -X PUT http://127.0.0.1:5984/"$db"/"$id" -d'{" type " : " wp_sql_db "}'

  local rev_id="$(curl -X GET http://127.0.0.1:5984/"$db"/"$id" | jq -r '._rev')"  #use jq library to process json

  echo "$rev_id"

  #export the wp datase
  #Get name of database and size and save to temporary file
  wp db size --format=json --allow-root > db_name.json
  local wp_sql_db_name="$(cat db_name.json | jq -r '.[].Name')"
  #echo "$wp_sql_db"

  #remove the temp file db_name.json
  rm db_name.json
  
  #Create the name that the exported database will have
  local exported_db_name="$wp_sql_db_name"_dbase-"$id".sql
  #export wp db to the current folder
  wp db export "$exported_db_name" --allow-root  

  #curl -vX PUT http://127.0.0.1:5984/db_name/doc_id/filename?rev=doc_rev_id --data-binary @filename -H "Content-Type:type of the content"
  #--data-binary@ - This option tells cURL to read a file’s contents into the HTTP request body.

  #curl -vX PUT http://127.0.0.1:5984/"$db"/"$id"/en-gcf2015.png?rev="$rev_id" --data-binary @en-gcf2015.png -H "ContentType:#image/png"

  curl -vX PUT http://127.0.0.1:5984/"$db"/"$id"/"$exported_db_name"?rev="$rev_id" --data-binary @"$exported_db_name" -H "ContentType: application/octet-stream"

  #remove the exported database or in future you can move it to a databases folder
  rm "$exported_db_name"

  ##To request the whole file from couchdb easily run the following command
  #curl -X GET http://127.0.0.1:5984/test/doc/file.txt
  curl -X GET http://127.0.0.1:5984/"$db"/"$id"/"$exported_db_name"
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
#***Writing views to couchdb using curl
#Examples on this site https://www.lullabot.com/articles/a-recipe-for-creating-couchdb-views
#Writing a view to get the date modified fields
#Working on writing wp posts from couchdb documents
#*** Playing with the education and healthcare plugins --look at how wpcli handles custom post types
#*** Look at polling wp plugin, surveys and custom forms/contactform 7
#Having our script run on boot and on shut down or every few minutes i.e cron, or see if we can listen for wp database changes
#Install cozy cloud on a raspberry pi
#**Have a function to sync a binary file i.e  image/video to an uploads/media file in the remote machine using rsync
#look for  a wordpress cloud storage plugin
#Wordpress post content pulls images from wp-content/uploads. find a way to make that url relative if exported to couch
#Also look at a plugin to rearrange the wp media folder: https://wpmayor.com/wp-media-folder-organize-sync-wordpress-media/
#Have an online login app that will direct a person to a WP instance that has the db they are interested in 
#Look at WP YOP Poll
#Look at nextcloud images folder

#Have the cloud operations handled with Nexcloud as usual, Adding photos e.t.c then sync the data folder to a server online
#then find out how i can get the synced folder data to nextcloud. Also how to transfer the user data
#could try syncing to the data folder an actual nextcloud instance

#looks like the folder structure of nextcloud is nextcloud/data/username/files
#-----------
##create a large filesystem on another disk (or elsewhere), integrate it into Nextcloud using the external storage app 
#and move the content there, which is how I manage my 42TB storage array whilst keeping it available via 
#other means (CIFs, SFTP, etc)

#config.php specifies the location.
#If you just want to "point" to existing files and not have to reupload everything to NC, use the external storage option.

#Guide to changing nextcloud data dir: https://help.nextcloud.com/t/howto-change-move-data-directory-after-installation/17170/12
#-------------
#Checking for new wordpress posts and uploading to couchdb  --Done
#  -Always have a copy of post IDS
#  -in a function read the text file and save the IDS in an array
#  -make another array of current wordpress post IDS
#  -compare the arrays and make another array with the difference in the 2 arrays. 
#  -then using the ids in the new array get their wordpress posts and convert them to couchdb database
#  -get all the wordpress current ids and rewrite the original IDS text file

#Updating a couchdb document with an updated wordpress post  --DONE
# -check date modified in couchdb document and match with the one in wordpress post if different then update the couchdb document
#  -in a loop using the id as the variable, get date_modified from couchdb document and from wordpress post and compare
#  -If the date modified in the wordpress post is greater than the couchdb document then update the couch document with the new wp post
# -couchdb: curl -X GET http://127.0.0.1:5984/"$db"/"$id" | jq -r '.post_modified'
# -wpcli: wp post get $id --field=post_modified --allow-root
# -get current date : DATE=`date '+%Y-%m-%d %H:%M:%S'`
# -convert date and time to number : todate=$(date -d "$DATE" +"%Y%m%d%H%M%S")   or for just date todate=$(date -d "$DATE" +"%Y%m%d")
# -

#Nice shell guide on files https://www.cyberciti.biz/faq/unix-linux-test-existence-of-file-in-bash/





