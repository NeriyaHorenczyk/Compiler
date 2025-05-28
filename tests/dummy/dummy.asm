//push constant 0
@0
D=A
@SP
A=M
M=D
@SP
M=M+1
//if-goto SKIP1
@SP
A=M-1
D=M
@SP
M=M-1
@input.SKIP1
D;JNE
//push constant 111
@111
D=A
@SP
A=M
M=D
@SP
M=M+1
//label SKIP1
(input.SKIP1)
//push constant 1
@1
D=A
@SP
A=M
M=D
@SP
M=M+1
//if-goto SKIP2
@SP
A=M-1
D=M
@SP
M=M-1
@input.SKIP2
D;JNE
//push constant 222
@222
D=A
@SP
A=M
M=D
@SP
M=M+1
//label SKIP2
(input.SKIP2)
//push constant 333
//Error!
