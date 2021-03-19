# zabbix-bluecoat TOP 
zabbix-bluecoat

Данный проект предназначен для получения данных с системы blue coat определение максимального числа соединений:
- с локальных адресов
- на удаленные адреса в сети интернет

Результат выполнения обработки, при помощи zabbix sender заливается в мониторинг, для отображения на дащьборде


cp ./BLUECOAT-MIB.mib /usr/share/snmp/mibs/

cp ./BLUECOAT-SG-PROXY-MIB.mib /usr/share/snmp/mibs/

cp ./bluecoat_top.pl /usr/zabbix/

crontab -e

*/10    *  *  *  *    /usr/zabbix/bluecoat_top.pl > /dev/null 2>&1

