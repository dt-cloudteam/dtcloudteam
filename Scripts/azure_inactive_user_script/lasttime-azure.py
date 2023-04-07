import requests
from datetime import date
import datetime
import csv

# Melih Selami Urkmez / Asrin Andirin


sessionhostlist=[]
inactive_users=[]
AZ_TOKEN="" # get access token command -> az account get-access-token --resource https://management.azure.com --query accessToken -o tsv
MONTH_THRESHOLD=6 # must be integer
SESSION_HOST_PATH=""
INACTIVE_USER_PATH=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
HOST_POOL=" "


headers = {
            'Authorization': 'Bearer {}'.format(AZ_TOKEN) ,
            'Content-Type': 'application/json'
        }
def months_between(date1, date2):
    d1 = datetime.datetime.strptime(date1, '%Y-%m-%d')
    d2 = datetime.datetime.strptime(date2, '%Y-%m-%d')
    delta = d2 - d1
    return int(delta.days) // 30

def string_formatter(name):
    slash_index=name.index('/')
    return name[slash_index+1:]

with open(SESSION_HOST_PATH) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        if line_count == 0:
            line_count+=1
            continue
        else:
            sessionhostlist.append([row[0],row[3]])
for x in sessionhostlist:
    url="https://management.azure.com/subscriptions/{}/resourceGroups/{}/providers/Microsoft.DesktopVirtualization/hostPools/{}/sessionHosts/{}?api-version=2021-03-09-preview".format(SUBSCRIPTION_ID,RESOURCE_GROUP,HOST_POOL,string_formatter(x[0]))
    r=requests.get(url,headers=headers)
    print(r.json())
    last_login=r.json()['properties']['lastHeartBeat'][0:10]
    if months_between(last_login,str(date.today()))>MONTH_THRESHOLD:
        inactive_users.append([x[0],x[1],str(months_between(last_login,str(date.today())))])
        print(x[0]+" "+x[1]+" "+str(months_between(last_login,str(date.today()))))
   
inactive_users.append(["SessionHost(Machine)","User","Not Login(Month)"])
with open(INACTIVE_USER_PATH, 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerows(inactive_users)
    
    
