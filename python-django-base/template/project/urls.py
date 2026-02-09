from django.contrib import admin
from django.urls import path
from django.http import HttpResponse

def health_check(request):
    return HttpResponse("ok")

def home(request):
    return HttpResponse("Hello World from Django")

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_check),
    path('', home),
]
