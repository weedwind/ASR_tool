form 
text tmpin  tmpin.wav
text tmpout tmpout.pitch
endform
Read from file... 'tmpin$'
# Autocorrealtion Method, Optimized for Intonation 
# Best setting for all voiced tracking 
To Pitch (ac)...  0.01 60 10 no  0.00 0.00 0.01 0.35 0.14 400

# CrossCorrealtion Method, Optimized for Voice Analysis 
# Best setting for voiced/unvoiced tracking 
# To Pitch (cc)...  0.01 75 10 no  0.03 0.45 0.01 0.35 0.14 600

# SPINET? Method
#To Pitch (SPINET)... 0.005 0.04  70 5000 250 500 15

# SHS (Spectral compression model) Method
#To Pitch (shs)... 0.01 60 15  650 15 0.84 400 48

Write to short text file... 'tmpout$'
