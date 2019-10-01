 rm -rf bin/
 mkdir -p bin/
 cd bin/
 zip -j api-lambda.zip ../api-lambda/*
 zip -j stream-lambda.zip ../stream-lambda/*
 cd ../