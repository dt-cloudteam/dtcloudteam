import csv
from datetime import date
import datetime
def months_between(date1, date2):
    d1 = datetime.datetime.strptime(date1, '%Y-%m-%d')
    d2 = datetime.datetime.strptime(date2, '%Y-%m-%d')
    delta = d2 - d1
    return delta.days // 30

today = date.today()
user_row_list=[]

with open('C:\gcp_users.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        if line_count == 0:
            user_row_list.append([row[0],row[1],row[2],"Ne kadar Giriş Yapılmadı?"])
            line_count+=1
            continue
        else:
            date=row[4].split(' ')[0].split('/')
            if(len(date)>2):
                date2=f'{date[0]}-{date[1]}-{date[2]}'
                if(months_between(date2,str(today))>4):
                    user_row_list.append([row[0],row[1],row[2],months_between(date2,str(today))])
                    print(f'\t Isim:{row[0]} {row[1]} Email:{row[2]} {months_between(date2,str(today))} ay giriş yapılmamış.')

            else:
                user_row_list.append([row[0],row[1],row[2],"Giris yapilmamis."])
                print(f'\t Isim:{row[0]} {row[1]} Email:{row[2]} hiç giriş yapmamış.')

            line_count += 1

with open('C:\inactive_users.csv', 'w', newline='') as file:
     writer = csv.writer(file)
     writer.writerows(user_row_list)