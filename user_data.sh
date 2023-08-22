#!/bin/bash
yum -y update
yum -y install httpd


myip=`curl http://checkip.amazonaws.com`

cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="blue">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v0.12</font></h2><br><p>
<font color="green">Server PrivateIP: <font color="aqua">$myip<br><br>

<font color="magenta">
<b>Version 3.1</b>
</body>
</html>
EOF

sudo service httpd start
chkconfig httpd on


