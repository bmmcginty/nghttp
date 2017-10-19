import requests,time
s=requests.session()
st=time.time()
for i in range(10000):
 url="http://httpbin.apps.bmcginty.us/"+str(i)
# print " "+str(i)
 t=s.get(url,stream=False)
# print t.status_code
 resp=t.content
# l=[]
# for i in resp.iter_content(16384):
#  l.append(i)
#print "".join(l)
# print t.headers
et=time.time()
print et-st

