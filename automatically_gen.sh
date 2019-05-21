#!/bin/bash

FILE="./generated.bash"

cat <<END > $FILE
#!/bin/bash

echo "Hello There from generated script!"
END

chmod 755 $FILE
echo "running ...."
$FILE
echo "done"
