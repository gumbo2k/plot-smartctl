plot-smartctl
=============

Leverage gnuplot to keep an eye on S.M.A.R.T. attributes over long periods of time.


Motivation
==========
After seeing a couple of hard drives fail I decided to use smartmontools 
more often. 
The output of "smartctl -a" is nice but most people will only read it _after_ 
their drive failed. There is a lot of information and most of it, detailed 
though it may be, is not even particularly useful when seen as a snapshot 
of the drive's current condition. Using "smartd" to send you messages might
work but you'd have to know what exactly to look out for. 

So I decided to take a "smartctl -a"-snapshot of every drive every day and
later look though it and mine it for trends. Well, a couple of years and
drives have gone by and I never got around to look through that pile of
files. All have the drive model, serial number, and time stamp in their
file name and the complete "smartcrl -a" output inside. All I needed now
was a way to visualize the data and make it more accessible.

I looked around but nothing really small and compact was around so I wrote
a simple script to collect the attribute data from those files and feed the
data to gnuplot for visualization.


What does it do?
================
The script will take file names from the command line, or will look for
the files if you give it a regex pattern for the file names and optionally
a directory to start looking.

Then it will sort those file names and for each file it will extract
a time stamp from the file name and the VALUE column from the attributes
table. The time stamp and the values are then written into a file and
gnuplot is called to make the data into a nice little graph.

Disclaimer
==========
My perl fu is rusty and I'd rather have sat down and written the whole
thing in python. If only I had the time to properly learn python...

So feel free to let me know if my perl code offends your sense of sense
of aesthetic. I'll feel free to ignore it unless it comes with a patch ;-)


