from bottle import Bottle, request, run

import subprocess
import datetime
import logging
import json
import tempfile
import os

ctxfile = None

logging.basicConfig(filename='/tmp/example.log',level=logging.DEBUG)

# generates a cli friendly string of aqbanking and all its parameters
def aqbanking(cmd, account_number=None, from_date=None, to_date=None,params=None, pinfile=None):
  global ctxfile

  ret = ['aqbanking-cli',cmd, '-c', ctxfile]

  # Unfortunately this has to prepend all other options including the command
  if pinfile:
    ret = ['aqbanking-cli', '-P', pinfile, cmd, '-c', ctxfile]

  # Here is what we append to the command
  if account_number:
    ret.extend(["-a", account_number])
  if from_date:
    ret.append("--fromdate=%s" % from_date)
  if to_date:
    ret.append("--todate=%s" % to_date)
  if params and type(params) == type([]):
    ret.extend(params)
  logging.debug(" ".join(ret))
  return ret

# makes a json string from class objects
class MyEncoder(json.JSONEncoder):
  def default(self, o):
    return o.__dict__

class Account(object):
  def __init__(self,account_number=None):
    self.statements=[]
    self.lastSettleDate = datetime.datetime.now().isoformat()
    self.isCreditCard=False
    self.balance=None
    self.account=account_number
    self.bankCode=None

  # TODO this is used for credit card detection
  def get_balance(self):
    proc = subprocess.Popen(aqbanking("listbal",self.account),stdout=subprocess.PIPE)
    line = proc.stdout.readline()
    line = line.rstrip('\n')
    if not line:
        self.isCreditCard = True
        return

    data = [ item for item in line.split('\t') if len(item) ]

    logging.debug(data)
    self.balance = data[-2]

  def __add_transaction(self,transaction):
    if self.account== transaction.account:
      if self.bankCode is None:
        self.bankCode = transaction.bankCode
      self.statements.append(transaction)
    else:
      raise ValueError('Accounts of Transaction and Account do not match', self.account, transaction.account)

  def get_transactions(self):
      proc = subprocess.Popen(aqbanking("listtrans",self.account),stdout=subprocess.PIPE)
      # Skip Header
      line = proc.stdout.readline().rstrip("\n")
      header = line.split('";"')
      for line in proc.stdout:
    	line = line.rstrip('\n')
        self.__add_transaction(Transaction(dict(zip(header, line.split('";"')))))
      return

class Transaction(object):
  def __init__(self, data):
    self.final=True
    self.bankCode=data["localBankCode"]
    self.account=data["localAccountNumber"]
    self.valutaDate=datetime.datetime.strptime(data["valutadate"], "%Y/%m/%d").isoformat()
    self.date=datetime.datetime.strptime(data["date"], "%Y/%m/%d").isoformat()

    self.remoteName = (data["remoteName"] + data["remoteName1"])

    if unicode(data["remoteBankCode"]).isnumeric():
        self.remoteBankCode = data["remoteBankCode"]
    else:
        self.remoteBIC = data["remoteBankCode"]

    if unicode(data["remoteAccountNumber"]).isnumeric():
        self.remoteAccount = data["remoteAccountNumber"]
    else:
        self.remoteIBAN = data["remoteAccountNumber"]

    self.transactionText="".join([ data[k] for k in sorted([ key for key in data if key.startswith("purpose") ]) ])
    self.value="%s %s" % (data["value_value"], data["value_currency"])
    self.originalValue=self.value


def update(from_date,to_date):
    global pinfile
    params = ["--sepaSto", "--dated", "--sto", "--balance", "--transactions", "--ignoreUnsupported"]
    proc = subprocess.Popen(aqbanking("request", from_date=from_date, to_date=to_date, params=params, pinfile=pinfile),stdout=subprocess.PIPE)
    logging.debug(proc.stdout.read())
    return

def get_account_numbers():
    accounts = []
    proc = subprocess.Popen(["aqbanking-cli", "listaccs"], stdout=subprocess.PIPE)
    for line in proc.stdout:
        data = line.split('\t')
        accounts.append(data[2])
    return accounts

def get_account(account_number):
    account=Account(account_number)
    account.get_transactions()
    account.get_balance()
    return account


######################################
#                                    #
#           CONFIG FILE              #
#                                    #
######################################

settings = {}

try:
    settings = json.load(open(os.path.join(os.path.expanduser("~"), ".pecunia-python.settings")))
except Exception as e:
    print e
    pass

pinfile = settings.get("pinfile", os.path.join(os.path.expanduser("~"), ".pinfile"))


######################################
#                                    #
#           MAIN STARTUP             #
#                                    #
######################################

app = Bottle()
logging.debug("Startup")

@app.route('/transactions')
def entry():
    accounts = request.query.accounts

    with tempfile.NamedTemporaryFile() as ctx:
        global ctxfile
        ctxfile = "/Users/elser/Downloads/transactions"
        #ctxfile = ctx.name
        logging.debug(ctxfile)

        from_date = request.query.from_date
        if from_date:
            from_date = float(from_date)
            from_date = datetime.datetime.fromtimestamp(from_date).date().strftime("%Y%m%d")

        to_date = request.query.to_date
        if to_date:
            to_date = float(to_date)
            to_date = datetime.datetime.fromtimestamp(to_date).date().strftime("%Y%m%d")

        # Download data via aqbanking-cli request
        update(from_date,to_date)

        known_accounts = get_account_numbers()

        if accounts == "":
            accounts = known_accounts
        else:
            accounts=accounts.split(",")
            accounts = list(set(accounts).intersection(set(known_accounts)))


        logging.debug("Accounts: " + " ".join(accounts))
        # From here there are only valid accounts
        # Filtering was done previously
        result = []
        for account in accounts:
            result.append(get_account(account))


    from bottle import response
    response.content_type = 'application/json'
    res = json.dumps(result, cls=MyEncoder)
    logging.debug("Sending Results %d chars" % len(res))
    return res

run(app, host='localhost', port=8000)
