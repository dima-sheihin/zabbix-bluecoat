# zabbix-bluecoat
zabbix-bluecoat

Данный проект предназначен для получения данных с системы blue coat определение максимального числа соединений:
- с локальных адресов
- на удаленные адреса в сети интернет

Результат выполнения обработки, при помощи zabbix sender заливается в мониторинг, для отображения на дащьборде


# crontab -e

*/10    *  *  *  *    /usr/zabbix/bluecoat_top.pl > /dev/null 2>&1

