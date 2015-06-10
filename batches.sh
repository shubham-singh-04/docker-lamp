#!/bin/bash
source /env
echo `date` ": recalc_privileges"
/var/www/html/vtigercrm/recalc_privileges.php
