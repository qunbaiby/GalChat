from __future__ import annotations

from cryptography.fernet import Fernet, InvalidToken


class ProviderSecretCipher:
    def __init__(self, master_key: str) -> None:
        self._fernet = Fernet(master_key.encode("ascii")) if master_key else None

    @property
    def is_configured(self) -> bool:
        return self._fernet is not None

    def encrypt(self, value: str) -> str:
        if self._fernet is None:
            raise RuntimeError("GALCHAT_SECRETS_MASTER_KEY is not configured.")
        return self._fernet.encrypt(value.encode("utf-8")).decode("ascii")

    def decrypt(self, encrypted_value: str) -> str:
        if self._fernet is None:
            raise RuntimeError("GALCHAT_SECRETS_MASTER_KEY is not configured.")
        try:
            return self._fernet.decrypt(encrypted_value.encode("ascii")).decode("utf-8")
        except InvalidToken as error:
            raise RuntimeError("Stored provider secret cannot be decrypted with the configured master key.") from error