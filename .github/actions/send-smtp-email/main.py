import smtplib

from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import formatdate
from email import encoders

def send_mail(smtp_enable_tls, smtp_server_address, smtp_server_port, smtp_username, smtp_password, email_from, email_to, email_subject, email_body, email_attachments):
  """Sends an email with attachment.
  :param smtp_enable_tls: Enable TLS for SMTP.
  :param smtp_server_address: SMTP server address.
  :param smtp_server_port: SMTP server port.
  :param smtp_username: SMTP username.
  :param smtp_password: SMTP password.
  :param email_from: From email address.
  :param email_to: To email address.
  :param email_subject: Email subject.
  :param email_body: Email body.
  :param email_attachments: Email attachments.
  """
  
  msg = MIMEMultipart()
  msg['From'] = email_from
  msg['To'] = ewmail_to
  msg['Date'] = formatdate(localtime=True)
  msg['Subject'] = email_subject
  msg.attach(MIMEText(email_body))
  
  part = MIMEBase('application', "octet-stream")
  part.set_payload(open(email_attachments, "rb").read())
  encoders.encode_base64(part)
  part.add_header('Content-Disposition', 'attachment; filename=' + email_attachments)
  msg.attach(part)
  
  smtp = smtplib.SMTP(smtp_server_address, smtp_server_port)
  try:
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
    smtp_enable_tls=os.getenv('SMTP_ENABLE_TLS')
    smtp_server_address=os.getenv('SMTP_SERVER_ADDRESS'),
    smtp_server_port=os.getenv('SMTP_SERVER_PORT'),
    smtp_username=os.getenv('SMTP_USERNAME'),
    smtp_password=os.getenv('SMTP_PASSWORD'),
    email_from=os.getenv('EMAIL_FROM'),
    email_to=os.getenv('EMAIL_TO'),
    email_subject=os.getenv('EMAIL_SUBJECT'),
    email_body=os.getenv('EMAIL_BODY'),
    email_attachments=os.getenv('EMAIL_ATTACHMENTS'),
  )

if __name__ == "__main__":
  main()