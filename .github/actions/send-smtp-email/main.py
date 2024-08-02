from os import getenv
from smtplib import SMTP, SMTPAuthenticationError
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import formatdate
from email import encoders

def send_mail(smtp_enable_tls: bool, smtp_server_address: str, smtp_server_port: int,
        smtp_username: str, smtp_password: str, email_from: str, email_to: str,
        email_cc: str, email_bcc: str, email_subject: str, email_body: str,
        email_attachments: str) -> None:
  """Sends an email with attachment.
  Args:
    smtp_enable_tls (bool): Enable TLS for SMTP.
    smtp_server_address (str): SMTP server address.
    smtp_server_port (int): SMTP server port.
    smtp_username (str): SMTP username.
    smtp_password (str): SMTP password.
    email_from (str): From email address.
    email_to (str): To email address.
    email_cc (str): CC email addresses.
    email_bcc (str): BCC email addresses.
    email_subject (str): Email subject.
    email_body (str): Email body.
    email_attachments (str): Email attachments.
  """

  msg = MIMEMultipart()
  recipients = email_cc.split(",") + email_bcc.split(",") + [email_to]
  msg['From'] = email_from
  msg['To'] = email_to
  if email_cc:
    msg['Cc'] = ",".join(email_cc)
  if email_bcc:
    msg['Bcc'] = ",".join(email_bcc)
  msg['Date'] = formatdate(localtime=True)
  msg['Subject'] = email_subject
  msg.attach(MIMEText(email_body))

  with open(email_attachments, "rb") as attachment:
    part = MIMEBase('application', "octet-stream")
    part.set_payload(attachment.read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', 'attachment', filename=email_attachments)
    msg.attach(part)

  try:
    smtp = SMTP(smtp_server_address, smtp_server_port)
    if smtp_enable_tls:
      smtp.ehlo()
      smtp.starttls()
      try:
        smtp.login(smtp_username, smtp_password)
        smtp.sendmail(msg['From'], recipients, msg.as_string())
      except SMTPAuthenticationError:
        raise SMTPAuthenticationError("Error: Authentication failed. Please check your SMTP credentials.")
    smtp.quit()
  except Exception as e:
    raise Exception("An error occurred while sending the email:", str(e))

def main() -> None:
  send_mail(
    smtp_enable_tls=getenv('SMTP_ENABLE_TLS'),
    smtp_server_address=getenv('SMTP_SERVER_ADDRESS'),
    smtp_server_port=getenv('SMTP_SERVER_PORT'),
    smtp_username=getenv('SMTP_USERNAME'),
    smtp_password=getenv('SMTP_PASSWORD'),
    email_from=getenv('EMAIL_FROM'),
    email_to=getenv('EMAIL_TO'),
    email_cc=getenv('EMAIL_CC'),
    email_bcc=getenv('EMAIL_BCC'),
    email_subject=getenv('EMAIL_SUBJECT'),
    email_body=getenv('EMAIL_BODY'),
    email_attachments=getenv('EMAIL_ATTACHMENTS'),
  )

if __name__ == "__main__":
  main()
