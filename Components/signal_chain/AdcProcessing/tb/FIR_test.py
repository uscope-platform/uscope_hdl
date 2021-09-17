'''
Copyright 2021 University of Nottingham Ningbo China
Author: Filippo Savi <filssavi@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'''

import socket, sys, time, math, ctypes
import numpy as np
from scipy.signal import firwin, kaiserord, convolve

def getSignedNumber(number, bitLength):
    mask = (2 ** bitLength) - 1
    if number & (1 << (bitLength - 1)):
        return number | ~mask
    else:
        return number & mask
def int_to_signed_short(value):
    return -(value & 0x8000) | (value & 0x7fff)

samples = np.sin(np.linspace(0,2*np.pi,365)-np.pi)*(2**15-1)

# Create a TCP/IP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Bind the socket to the port
server_address = ('localhost', 1234)
print(f'starting up on {server_address[0]} port {server_address[1]}')
sock.bind(server_address)

# Listen for incoming connections
sock.listen(1)

# Wait for a connection
#print('waiting for a connection')
connection, client_address = sock.accept()
connection.settimeout(0.3)
try:
    #print(f'connection from {client_address}')

    test_Rec = []
    # Receive the data in small chunks and retransmit it
    for idx,val in enumerate(samples):
        to_send = str(int(val))+'\n'
        connection.sendall(to_send.encode('utf-8'))
        if idx> 3: 
            test_Rec.append(int(connection.recv(1000)))
    
    while True:
        try:
            raw = connection.recv(100000)
        except socket.timeout:
            break
        val_list = raw.decode("utf-8").split('\n')
        if val_list == ['']:
            break
        val_list.remove('')
        test_Rec = test_Rec + list(map(int, val_list))
    
    test_result = test_Rec
    #print(test_result) 
finally:
    # Clean up the connection
    connection.close()

# The Nyquist rate of the signal.
nyq_rate = 100e6 / 2.0
width = 9.99e6/nyq_rate
ripple_db = 19.0
N, beta = kaiserord(ripple_db, width)
cutoff_hz = 10e6
taps = firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))

#load filter input and output
filter_out = test_Rec
filter_in = samples

#remove all odd values that come from falling clock edges
filter_in = filter_in[0:]
filter_out = filter_out[0:]

print(filter_out[8])

#discard first output values due to pipelining
filter_out = np.floor(np.array(filter_out[8:]))

#unsigned -> signed
filter_in_s = []
for i in filter_in:
    filter_in_s.append(ctypes.c_short(int(math.floor(i))).value)

filter_out_s = []
for i in filter_out:
    filter_out_s.append(ctypes.c_short(int(math.floor(i))).value)

#tap quantization
taps_q = np.floor(taps*2**16)/2**16

correct_results = np.fix(convolve(taps_q, filter_in_s)).astype(int).tolist()
correct_results = correct_results[9:]
abs_error = abs(np.array(correct_results)-np.array(filter_out_s))
rel_error = np.mean(abs_error)/(max(filter_in_s)+abs(min(filter_in_s)))
percentage_error = rel_error*100
if(percentage_error<1):
    print('FIR FILTER TEST SUCCEDED')
    exit(0)
else:
    print('FIR FILTER TEST FAILED')
    print(f'Absolute error: {abs_error}\nRelative error: {rel_error}\nPercentage error: {percentage_error}')
    exit(1)