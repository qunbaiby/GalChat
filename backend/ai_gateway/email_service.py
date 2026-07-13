from __future__ import annotations

import os
import smtplib
from email.message import EmailMessage


class EmailService:
    def __init__(self) -> None:
        self.mode = os.getenv("GALCHAT_EMAIL_MODE", "console").strip().lower()
        self.host = os.getenv("GALCHAT_SMTP_HOST", "").strip()
        self.port = int(os.getenv("GALCHAT_SMTP_PORT", "587"))
        self.username = os.getenv("GALCHAT_SMTP_USERNAME", "").strip()
        self.password = os.getenv("GALCHAT_SMTP_PASSWORD", "")
        self.sender = os.getenv("GALCHAT_EMAIL_FROM", self.username).strip()
        self.use_tls = os.getenv("GALCHAT_SMTP_USE_TLS", "true").lower() == "true"

    def configuration_errors(self) -> list[str]:
        if self.mode == "console":
            return []
        errors: list[str] = []
        if self.mode != "smtp":
            errors.append("GALCHAT_EMAIL_MODE must be console or smtp")
        if not self.host:
            errors.append("GALCHAT_SMTP_HOST must be configured")
        if not 1 <= self.port <= 65535:
            errors.append("GALCHAT_SMTP_PORT must be between 1 and 65535")
        if not self.sender or "@" not in self.sender:
            errors.append("GALCHAT_EMAIL_FROM must be a valid sender address")
        if self.username and not self.password:
            errors.append("GALCHAT_SMTP_PASSWORD is required when GALCHAT_SMTP_USERNAME is configured")
        return errors

    def is_configured(self) -> bool:
        return not self.configuration_errors()

    def send_verification_code(self, email: str, code: str) -> None:
        if self.mode == "console":
            print(f"[GalChat verification] {email}: {code}")
            return
        if not self.host or not self.sender:
            raise RuntimeError("SMTP is not configured.")
        message = EmailMessage()
        message["Subject"] = "GalChat 注册验证码"
        message["From"] = self.sender
        message["To"] = email
        message.set_content(f"你的 GalChat 注册验证码是：{code}\n\n验证码 10 分钟内有效，请勿转发。")
        with smtplib.SMTP(self.host, self.port, timeout=15) as smtp:
            if self.use_tls:
                smtp.starttls()
            if self.username:
                smtp.login(self.username, self.password)
            smtp.send_message(message)

    def send_password_reset_code(self, email: str, code: str) -> None:
        if self.mode == "console":
            print(f"[GalChat password reset] {email}: {code}")
            return
        if not self.host or not self.sender:
            raise RuntimeError("SMTP is not configured.")
        message = EmailMessage()
        message["Subject"] = "GalChat 密码重置验证码"
        message["From"] = self.sender
        message["To"] = email
        message.set_content(f"你的 GalChat 密码重置验证码是：{code}\n\n验证码 10 分钟内有效，请勿转发。")
        with smtplib.SMTP(self.host, self.port, timeout=15) as smtp:
            if self.use_tls:
                smtp.starttls()
            if self.username:
                smtp.login(self.username, self.password)
            smtp.send_message(message)
