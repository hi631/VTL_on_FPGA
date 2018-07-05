@@echo off
C:\app2\iverilog\bin\iverilog -o td4.o rs232c.v ps2_rx.v td4.v td4_tb.v
C:\app2\iverilog\bin\vvp td4.o
timeout 3
C:\app2\iverilog\gtkwave\bin\gtkwave wave.vcd -a td4.gtkw
del td4.o wave.vcd
