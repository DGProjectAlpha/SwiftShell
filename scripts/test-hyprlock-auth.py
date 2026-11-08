#!/usr/bin/env python3
"""Test the current user's Hyprlock PAM authentication without locking.

The password is entered only in this local dialog, never through argv, files,
environment variables or stdout. One attempt per invocation avoids retry loops.
No session is opened, no locker is launched and no PAM settings are changed.
"""
import ctypes as C
import ctypes.util
import argparse
import json
import os
import pwd
import sys


def authenticate(password):
    pam = C.CDLL(ctypes.util.find_library('pam'))
    libc = C.CDLL(None)

    class Message(C.Structure):
        _fields_ = [('style', C.c_int), ('text', C.c_char_p)]

    class Response(C.Structure):
        _fields_ = [('text', C.c_void_p), ('code', C.c_int)]

    callback_type = C.CFUNCTYPE(C.c_int, C.c_int, C.POINTER(C.POINTER(Message)), C.POINTER(C.POINTER(Response)), C.c_void_p)
    username = pwd.getpwuid(os.getuid()).pw_name.encode()
    libc.calloc.argtypes = [C.c_size_t, C.c_size_t]
    libc.calloc.restype = C.c_void_p
    libc.strdup.argtypes = [C.c_char_p]
    libc.strdup.restype = C.c_void_p
    libc.free.argtypes = [C.c_void_p]

    @callback_type
    def conversation(count, messages, output, _):
        if count < 1 or count > 32:
            return 19  # PAM_CONV_ERR
        allocation = libc.calloc(count, C.sizeof(Response))
        if not allocation:
            return 5  # PAM_BUF_ERR
        responses = C.cast(allocation, C.POINTER(Response))
        for index in range(count):
            style = messages[index].contents.style
            if style in (1, 2):
                responses[index].text = libc.strdup(password if style == 1 else username)
            elif style not in (3, 4):
                for previous in range(index):
                    if responses[previous].text:
                        libc.free(responses[previous].text)
                libc.free(allocation)
                return 19
        output[0] = responses
        return 0

    class Conversation(C.Structure):
        _fields_ = [('callback', callback_type), ('data', C.c_void_p)]

    pam.pam_start.argtypes = [C.c_char_p, C.c_char_p, C.POINTER(Conversation), C.POINTER(C.c_void_p)]
    pam.pam_authenticate.argtypes = [C.c_void_p, C.c_int]
    pam.pam_end.argtypes = [C.c_void_p, C.c_int]
    handle = C.c_void_p()
    conv = Conversation(conversation, None)
    code = pam.pam_start(b'hyprlock', username, C.byref(conv), C.byref(handle))
    if code == 0:
        try:
            code = pam.pam_authenticate(handle, 0)
        finally:
            pam.pam_end(handle, code)
    return {'service': 'hyprlock', 'authenticated': code == 0, 'pamCode': code}


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    from PySide6.QtCore import QThread, Signal, QTimer
    from PySide6.QtWidgets import QApplication, QDialog, QLabel, QLineEdit, QPushButton, QVBoxLayout

    class Check(QThread):
        finished_check = Signal(dict)

        def run(self):
            try:
                result = authenticate(self.password)
            except Exception:
                result = {'service': 'hyprlock', 'authenticated': False, 'testError': True}
            finally:
                self.password = b''
            self.finished_check.emit(result)

    app = QApplication(sys.argv)
    window = QDialog()
    window.setWindowTitle('SwiftShell — safe Hyprlock authentication test')
    layout = QVBoxLayout(window)
    label = QLabel('This tests your usual login password without locking the screen.\n'
                   'One attempt only. Your password is never saved or printed.')
    layout.addWidget(label)
    field = QLineEdit()
    field.setEchoMode(QLineEdit.EchoMode.Password)
    field.setPlaceholderText('Your Linux login password')
    layout.addWidget(field)
    button = QPushButton('Test authentication')
    layout.addWidget(button)
    close = QPushButton('Close without locking')
    layout.addWidget(close)
    worker = Check(window)

    def start():
        if not field.text() or worker.isRunning():
            return
        worker.password = field.text().encode()
        field.clear()
        field.setEnabled(False)
        button.setEnabled(False)
        close.setEnabled(False)
        label.setText('Checking Hyprlock authentication… The desktop remains unlocked.')
        worker.start()

    def result(value):
        print(json.dumps(value), flush=True)
        label.setText('Authentication succeeded. Your password works with Hyprlock.' if value['authenticated']
                      else 'Authentication failed. No lock was taken. The result code was reported for diagnosis.')
        close.setEnabled(True)
        QTimer.singleShot(5000, window.accept)

    worker.finished_check.connect(result)
    button.clicked.connect(start)
    field.returnPressed.connect(start)
    close.clicked.connect(window.reject)
    # Do not destroy a running PAM thread if the user closes the test window.
    window.finished.connect(lambda _: worker.wait())
    window.resize(540, 180)
    window.show()
    field.setFocus()
    return app.exec()


if __name__ == '__main__':
    raise SystemExit(main())
