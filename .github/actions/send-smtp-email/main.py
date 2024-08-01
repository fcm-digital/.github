from os import getenv
from smtplib import SMTP

from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import formatdate
from email import encoders

def send_mail(smtp_enable_tls, smtp_server_address, smtp_server_port, smtp_username, smtp_password, email_from, email_to, email_subject, email_body, email_attachments):
  """Sends an email with attachment.
  Args:
    smtp_enable_tls (bool): Enable TLS for SMTP.
    smtp_server_address (str): SMTP server address.
    smtp_server_port (int): SMTP server port.
    smtp_username (str): SMTP username.
    smtp_password (str): SMTP password.
    email_from (str): From email address.
    email_to (str): To email address.
    email_subject (str): Email subject.
    email_body (str): Email body.
    email_attachments (str): Email attachments.
  """
  
  msg = MIMEMultipart()
  msg['From'] = email_from
  msg['To'] = email_to
  msg['Date'] = formatdate(localtime=True)
  msg['Subject'] = email_subject
  msg.attach(MIMEText(email_body))
  
  part = MIMEBase('application', "octet-stream")
  part.set_payload(open(email_attachments, "rb").read())
  encoders.encode_base64(part)
  part.add_header('Content-Disposition', 'attachment; filename=' + email_attachments)
  msg.attach(part)
  
  try:
    smtp = SMTP(smtp_server_address, smtp_server_port)
    if smtp_enable_tls:
      smtp.ehlo()
      smtp.starttls()
      smtp.login(smtp_username, smtp_password)
      smtp.sendmail(msg['From'], [msg['To']], msg.as_string())
    smtp.quit()
  except Exception as e:
    print("An error occurred while sending the email:", str(e))

def main():
  send_mail(
    smtp_enable_tls=getenv('SMTP_ENABLE_TLS'),
    smtp_server_address=getenv('SMTP_SERVER_ADDRESS'),
    smtp_server_port=getenv('SMTP_SERVER_PORT'),
    smtp_username=getenv('SMTP_USERNAME'),
    smtp_password=getenv('SMTP_PASSWORD'),
    email_from=getenv('EMAIL_FROM'),
    email_to=getenv('EMAIL_TO'),
    email_subject=getenv('EMAIL_SUBJECT'),
    email_body=getenv('EMAIL_BODY'),
    email_attachments=getenv('EMAIL_ATTACHMENTS'),
  )

if __name__ == "__main__":
  main()