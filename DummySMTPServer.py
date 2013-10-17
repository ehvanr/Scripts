# Written by Evan Reichard (August 2013)
# http://www.evanreichard.com/?p=64
# Requires pywin32

# This is a Python program that can be installed as a Windows Service.  It creates rolling log files in the "C:\DummySMTPLogs\" dir. 
# It does not send any emails it recieves, it's only for debugging purposes. 

# To install as service: python DummySMTP.py install
# It will be called “SMTP Dummy Server” in Services.msc

import win32serviceutil
import win32service
import win32event

import servicemanager
import threading
import asyncore
import smtpd
import time
import sys
import os

class AppServerSvc (win32serviceutil.ServiceFramework):
	_svc_name_ = "SMTPDummyServer"
	_svc_display_name_ = "SMTP Dummy Server"

	def __init__(self,args):
		win32serviceutil.ServiceFramework.__init__(self,args)
		self.hWaitStop = win32event.CreateEvent(None,0,0,None)

	def SvcStop(self):
		self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
		win32event.SetEvent(self.hWaitStop)
	def SvcDoRun(self):
		self.ReportServiceStatus(win32service.SERVICE_RUNNING)

		if not os.path.exists("C:\\DummySMTPLogs\\"):
			os.makedirs("C:\\DummySMTPLogs\\")

		server = smtpd.DebuggingServer(('0.0.0.0', 25), None)
		asyncoreThread = threading.Thread(target=asyncore.loop,kwargs = {'timeout':1})
		asyncoreThread.start()
		myStatusThread = threading.Thread(target=win32event.WaitForSingleObject, args=(self.hWaitStop, win32event.INFINITE))
		myStatusThread.start()

		while True:
			if myStatusThread.isAlive():
				fileName = time.strftime("%Y%m%d")
				completePath = os.path.abspath("C:\DummySMTPLogs\%s.log" % fileName)
				sys.stdout = open(completePath, 'a')
			else:
				self.server.close()
				self.asyncoreThread.join()
				break

			time.sleep(1)

if __name__ == '__main__':
    win32serviceutil.HandleCommandLine(AppServerSvc)