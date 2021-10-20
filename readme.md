# Archlinux Installationsscript

Mit diesem Script kann eine verschlüsselte Archlinux installation durchgeführt werden. 

Das ganze funktioniert auch nur mit UEFI! 

Ein Dualboot ist mit diesem Script nicht möglich. 

Es läuft weitgehend automatisch ab, ausser Benutzername, Hostnamen und Desktop wird nichts weiter abgefragt. 

Das Script nicht wirklich Einsteigerfreundlich. Man sollte schon wissen was man macht und vor allem schon mal eine Archlinux-Installation durchgeführt haben. 
Es ist nur eine Ergänzung bzw. Erleichterung um sich einiges an Tipparbeit zu ersparen.

Es werden folgende Partitionen erstellt (Verschlüsselte Installation):
* 512 MB für /boot
* 50 GB für /root
* 8 GB für swap 
* Der rest ist für /home vorgesehen. 


Für den Sway - Desktop ist keine Login-Manager dabei, der User meldet sich auf der Konsole an und kann mit 'sway' den Desktop starten. 