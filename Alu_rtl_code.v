// define an MACRO for changing the width of the RES if the CMD is multiplication
`define MUL
//WIDTH is for operands width CMD_WIDTH is for command width
module ALU_rtl_design #(parameter WIDTH = 4,parameter CMD_WIDTH=4)(OPA,OPB,CIN,CLK,RST,CMD,CE,MODE,INP_VALID,COUT,OFLOW,RES,G,E,L,ERR);
    input [WIDTH - 1:0] OPA,OPB;//Two operands
    input CLK,RST,CE,MODE,CIN;//clock,reset,clock enable,mode,carry in
    input [CMD_WIDTH-1:0] CMD;//command
    input [1:0]INP_VALID;//input valid

    output reg COUT;//carry out
    output reg OFLOW;//overflow
    output reg G;//greater than
    output reg E;//equality
    output reg L;//lesser than
    output reg ERR;//error flag

    `ifdef MUL//if the command is of multiplication
        output reg[2*WIDTH:0] RES;//RES should be two times of the RES
     `else
        output reg[WIDTH:0] RES;//otherwise RES should be WIDTH
     `endif

    localparam max_rotate_bits = $clog2(WIDTH);//Finds how many bits are required to rotate the value (in the 2^n=width it finds the n value
    reg [max_rotate_bits - 1:0] i;//register to store the value of i
    reg [max_rotate_bits -1 :0] rotate_value;// register to store the value of operand b
    reg [WIDTH:0] temp1_RES;//To maintain the delay part
    reg [2*WIDTH:0] mul_temp1_RES,temp2_RES;// to maintain the delay part for the multiplication
    reg temp1_COUT,temp1_OFLOW,temp1_G,temp1_E,temp1_L,temp1_ERR;//temporary register for other operation than multiplication
    reg temp2_OFLOW;//temporary register for the multiplication
    reg [WIDTH-1:0]temp_OPA,temp_OPB;
    reg [WIDTH:0]temp1_OPA,temp1_OPB;//temporary register for operands
    reg [CMD_WIDTH -1:0] temp_CMD,prev_temp_CMD;//for multiplication
    reg signed [WIDTH-1:0] sign_OPA,sign_OPB;//signed register for signed addition and signed subtraction
    reg signed [WIDTH : 0] sign_RES;//to store the signed result
    //FOR MODE=1 these are the commands
    localparam[CMD_WIDTH-1:0] ADD = 4'b0000,
                              SUB = 4'b0001,
                          ADD_CIN = 4'b0010,
                          SUB_CIN = 4'b0011,
                            INC_A = 4'b0100,
                            DEC_A = 4'b0101,
                            INC_B = 4'b0110,
                            DEC_B = 4'b0111,
                              CMP = 4'b1000,
                             MUL1 = 4'b1001,
                             MUL2 = 4'b1010,
                         ADD_SIGN = 4'b1011,
                         SUB_SIGN = 4'b1100;
 //FOR MODE=0 these are the commands
    localparam[CMD_WIDTH-1:0] AND = 4'b0000,
                             NAND = 4'b0001,
                               OR = 4'b0010,
                              NOR = 4'b0011,
                              XOR =4'b0100,
                             XNOR = 4'b0101,
                            NOT_A = 4'b0110,
                            NOT_B = 4'b0111,
                           SHR1_A = 4'b1000,
                           SHL1_A = 4'b1001,
                           SHR1_B = 4'b1010,
                           SHL1_B = 4'b1011,
                          ROL_A_B = 4'b1100,
                          ROR_A_B = 4'b1101;
    always@(posedge CLK or posedge RST)begin
    //initialization if reset
        if(RST)begin
            `ifdef MUL
                RES = {2*WIDTH+1{1'b0}};
            `else
                RES = {WIDTH+1{1'b0}};
             `endif
            ERR = 1'b0;
            OFLOW = 1'b0;
            COUT = 1'b0;
            G = 1'b0;
            E = 1'b0;
            L = 1'b0;
            prev_temp_CMD = 1'b0;
        end
        else begin // else store the operands to the temporary operand register
            temp_OPA <= OPA;
            temp_OPB <= OPB;
            prev_temp_CMD <= temp_CMD;
            temp_CMD <= CMD;
            if(temp_CMD == MUL1 || temp_CMD == MUL2)begin // if operation is multiplication then store temporary output register to another temporary output register for 3 clock delay
                temp2_RES <= mul_temp1_RES;
                temp2_OFLOW <= temp1_OFLOW;
            end
            else begin //else store the value of temporary output register to actual output register for two clock delay
                RES <= temp1_RES;
                ERR <= temp1_ERR;
                OFLOW <= temp1_OFLOW;
                COUT <= temp1_COUT;
                G <= temp1_G;
                E <= temp1_E;
                L <= temp1_L;
            end
            end
            if(prev_temp_CMD == MUL1 || prev_temp_CMD == MUL2) begin // if multiplication then assign second temporary output register to the actual output register
                RES <= temp2_RES;
                ERR <= temp1_ERR;
                OFLOW <= temp2_OFLOW;
                COUT <= temp1_COUT;
                G <= temp1_G;
                E <= temp1_E;
                L <= temp1_L;
            end
        end
        always@(*)begin // initializing all the output to zero
            `ifdef MUL
                mul_temp1_RES = {2*WIDTH+1{1'b0}};
             `else
                mul_temp1_RES = {WIDTH+1{1'b0}};
              `endif
            temp1_RES = {WIDTH+1{1'b0}};
            temp1_ERR = 1'b0;
            temp1_OFLOW = 1'b0;
            temp1_COUT = 1'b0;
            temp1_G = 1'b0;
            temp1_E = 1'b0;
            temp1_L = 1'b0;
            if(CE)begin //if clock enable is high
                //INP_VALID==00 PERFROMS NOTHING
                if(INP_VALID == 2'b00)begin // all the output register should be zero
                    `ifdef MUL
                        mul_temp1_RES = {2*WIDTH+1{1'b0}};
                    `else
                        mul_temp1_RES = {WIDTH{1'b0}};
                    `endif
                    temp1_RES = {WIDTH+1{1'b0}};
                    temp1_ERR = 1'b0;
                    temp1_OFLOW = 1'b0;
                    temp1_COUT = 1'b0;
                    temp1_G = 1'b0;
                    temp1_E = 1'b0;
                    temp1_L = 1'b0;
                end
                else if(INP_VALID == 2'b01)begin //if input valid is 01
                    if(MODE)begin //for mode =1
                        case(temp_CMD)
                            INC_A : begin// increment OPA by 1
                                    temp1_RES = temp_OPA + 1;
                                    temp1_COUT = (temp1_RES[WIDTH]);//check for cout
                                    end
                            DEC_A : begin    //decrement OPA by 1
                                    temp1_RES = temp_OPA - 1;
                                    temp1_OFLOW = (temp_OPA == 0) ? 1 : 0; // check for overflow
                                    end
                          default : begin // default case
                                   `ifdef MUL
                                         temp1_RES = {2*WIDTH+1{1'b0}};
                                    `else
                                          temp1_RES = {WIDTH{1'b0}};
                                    `endif
                                    temp1_RES = {WIDTH+1{1'b0}};
                                    temp1_ERR = 1'b0;
                                    temp1_OFLOW = 1'b0;
                                    temp1_COUT = 1'b0;
                                    temp1_G = 1'b0;
                                    temp1_E = 1'b0;
                                    temp1_L = 1'b0;
                                    end
                        endcase
                end
                else begin // if mode = 0
                    case(temp_CMD)
                        NOT_A : begin // not of OPA
                                    temp1_RES = {1'b0,~temp_OPA};
                                end
                       SHR1_A : begin // shift right OPA by 1
                                    temp1_RES = {1'b0,temp_OPA >> 1};
                                end
                       SHL1_A : begin // shift left OPA by 1
                                    temp1_RES = {1'b0,temp_OPA << 1};
                                end
                      default : begin // default case
                                    `ifdef MUL
                                        temp1_RES = {2*WIDTH+1{1'b0}};
                                    `else
                                        temp1_RES = {WIDTH{1'b0}};
                                    `endif
                                    temp1_RES = {WIDTH+1{1'b0}};
                                    temp1_ERR = 1'b0;
                                    temp1_OFLOW = 1'b0;
                                    temp1_COUT = 1'b0;
                                    temp1_G = 1'b0;
                                    temp1_E = 1'b0;
                                    temp1_L = 1'b0;
                                end
                    endcase
                end
            end
            else if(INP_VALID == 2'b10)begin // if input valid is 10
                if(MODE)begin // if mode = 1
                    case(temp_CMD)
                        INC_B : begin // increment OPB by 1
                                    temp1_RES = temp_OPB + 1;
                                    temp1_COUT = (temp1_RES[WIDTH]); // check for cout
                                end
                        DEC_B : begin // decrement OPB by 1
                                    temp1_RES = temp_OPB - 1;
                                    temp1_OFLOW = (temp_OPB == 0) ? 1 : 0; // check for overflow
                                end
                      default : begin //default case
                                   `ifdef MUL
                                        temp1_RES = {2*WIDTH+1{1'b0}};
                                    `else
                                        temp1_RES = {WIDTH{1'b0}};
                                    `endif
                                    temp1_RES = {WIDTH+1{1'b0}};
                                    temp1_ERR = 1'b0;
                                    temp1_OFLOW = 1'b0;
                                    temp1_COUT = 1'b0;
                                    temp1_G = 1'b0;
                                    temp1_E = 1'b0;
                                    temp1_L = 1'b0;
                                end
                    endcase
                end
                else begin //if mode = 0
                    case(temp_CMD)
                        NOT_B : begin // not of OPB
                                    temp1_RES = {1'b0,~temp_OPB};
                                end
                       SHR1_B : begin //shift right OPB by 1
                                    temp1_RES = {1'b0,temp_OPB >> 1};
                                end
                       SHL1_B : begin // shift left OPB by 1
                                    temp1_RES = {1'b0,temp_OPB << 1};
                                end
                      default : begin // default case
                                   `ifdef MUL
                                        temp1_RES = {2*WIDTH+1{1'b0}};
                                    `else
                                        temp1_RES = {WIDTH{1'b0}};
                                    `endif
                                    temp1_RES = {WIDTH+1{1'b0}};
                                    temp1_ERR = 1'b0;
                                    temp1_OFLOW = 1'b0;
                                    temp1_COUT = 1'b0;
                                    temp1_G = 1'b0;
                                    temp1_E = 1'b0;
                                    temp1_L = 1'b0;
                                end
                    endcase
                end
            end
            else begin // if input valid = 11
                if(MODE)begin //if mode = 1
                    case(temp_CMD)
                        ADD : begin // addition of OPA and OPB
                                  temp1_RES = temp_OPA + temp_OPB ;
                                  temp1_COUT = (temp1_RES[WIDTH]); // check for cout
                              end
                        SUB : begin // subtraction of OPA and OPB
                                  temp1_RES = temp_OPA - temp_OPB;
                                  temp1_OFLOW = (temp_OPA < temp_OPB);//check for overflow
                              end
                    ADD_CIN : begin //addition with carry in
                                  temp1_RES = temp_OPA + temp_OPB + CIN;
                                  temp1_COUT = (temp1_RES[WIDTH]);//check for cout
                              end
                    SUB_CIN : begin
                                  temp1_RES = temp_OPA - temp_OPB - CIN;//subtraction with carry in
                                  temp1_OFLOW = (((temp_OPA == temp_OPB) && (CIN == 1)) || (temp_OPA < temp_OPB))  ? 1 : 0;//check for overflow
                              end
                        CMP : begin// comparision of OPA and OPB
                                  if(temp_OPB == temp_OPA)begin //check for equality
                                      temp1_E = 1;
                                  end
                                  else if(temp_OPA > temp_OPB)begin // check for greater than
                                      temp1_G = 1;
                                  end
                                  else begin //check for lesser than
                                      temp1_L = 1;
                                  end
                              end
                       MUL1 : begin //increment and mutiplication
                                 `ifdef MUL // if MUL is is defined
                                  temp1_OPA = temp_OPA +1;

                                  temp1_OPB = temp_OPB +1;
                                  mul_temp1_RES = temp1_OPA * temp1_OPB;
                                  temp1_OFLOW=(mul_temp1_RES > {WIDTH+1{1'b1}}); //checking for overflow
                                  `endif
                              end
                       MUL2 : begin // shift OPA by 1 to left and multiply
                                 `ifdef MUL
                                  temp1_OPA = {temp_OPA << 1}; //shifting OPA
                                  temp1_OPB = temp_OPB;
                                  mul_temp1_RES = temp1_OPA * temp1_OPB;
                                  temp1_OFLOW=(mul_temp1_RES > {WIDTH+1{1'b1}});//checking for overflow
                                  `endif
                              end
                   ADD_SIGN : begin//signed addition
                                  sign_OPA = temp_OPA;//storing to signed register
                                  sign_OPB = temp_OPB;//storing to signed register
                                  sign_RES = sign_OPA + sign_OPB;
                                  temp1_RES = sign_RES;
                                  temp1_OFLOW = ((temp_OPA[WIDTH-1] == temp_OPB[WIDTH-1]) && (sign_RES[WIDTH-1] != temp_OPA[WIDTH - 1])) ? 1 : 0;  //checking for overflow
                                  temp1_G = (sign_OPA > sign_OPB) ? 1 : 0;//checking for greater than
                                  temp1_L = (sign_OPA < sign_OPB) ? 1 : 0;//checking for lesser than
                                  temp1_E = (sign_OPA == sign_OPB) ? 1 : 0;//checking for equality
                              end
                   SUB_SIGN : begin //signed subtraction
                                  sign_OPA = temp_OPA;//storing to signed register
                                  sign_OPB = temp_OPB;//storing to signed register
                                  sign_RES = sign_OPA - sign_OPB;
                                  temp1_RES = sign_RES;
                                  temp1_OFLOW = ((temp_OPA[WIDTH-1] != temp_OPB[WIDTH-1]) && (sign_RES[WIDTH-1] != temp_OPA[WIDTH - 1])) ? 1 : 0;
                                  temp1_G = (sign_OPA > sign_OPB) ? 1 : 0;
                                  temp1_L = (sign_OPA < sign_OPB) ? 1 : 0;
                                  temp1_E = (sign_OPA == sign_OPB) ? 1 : 0;
                              end
                    default : begin
                                `ifdef MUL
                                        mul_temp1_RES = {2*WIDTH+1{1'b0}};
                                   `else
                                        mul_temp1_RES = {WIDTH{1'b0}};
                                    `endif
                                  temp1_RES = {WIDTH +1{1'b0}};
                                  temp1_ERR = 1'b0;
                                  temp1_OFLOW = 1'b0;
                                  temp1_COUT = 1'b0;
                                  temp1_G = 1'b0;
                                  temp1_E = 1'b0;
                                  temp1_L = 1'b0;
                              end
                    endcase
                end
                else begin
                    case(temp_CMD)
                            AND : begin
                                      temp1_RES = {1'b0,(temp_OPA & temp_OPB)};
                                  end
                           NAND : begin
                                      temp1_RES = {1'b0,~(temp_OPA & temp_OPB)};
                                  end
                             OR : begin
                                      temp1_RES = {1'b0,(temp_OPA | temp_OPB)};
                                  end
                            NOR : begin
                                      temp1_RES = {1'b0,~(temp_OPA | temp_OPB)};
                                  end
                            XOR : begin
                                      temp1_RES = {1'b0,(temp_OPA ^ temp_OPB)};
                                  end
                           XNOR : begin
                                      temp1_RES = {1'b0,~(temp_OPA ^ temp_OPB)};
                                  end
                        ROL_A_B : begin
                                     rotate_value = OPB[max_rotate_bits - 1:0];
                                     //LEFT_SHIFT THE OPA BY ROTATE_VALUE & OR IT WITH THE (RIGHT_SHIFT OPA  BY(WIDTH-ROTATE)
                                     temp1_RES <= {1'b0,((temp_OPA << rotate_value ) | (temp_OPA >> WIDTH - rotate_value))};
                                     temp1_ERR <= (temp_OPB > WIDTH -1) ? 1 : 0;
                                  end
                        ROR_A_B : begin
                                      rotate_value = OPB[max_rotate_bits - 1:0];
                                      //RIGHT_SHIFT THE OPA BY ROTATE_VALUE & OR IT WITH THE (LEFT SHIFT OPA  BY(WIDTH-ROTATE)
                                      temp1_RES <= {1'b0,((temp_OPA >> rotate_value ) | (temp_OPA << WIDTH - rotate_value))};
                                      temp1_ERR <= (temp_OPB > WIDTH -1) ? 1 : 0;
                                  end
                        default : begin
                                      `ifdef MUL
                                            temp1_RES = {2*WIDTH+1{1'b0}};
                                       `else
                                            temp1_RES = {WIDTH{1'b0}};
                                        `endif
                                      temp1_RES = {WIDTH+1{1'b0}};
                                      temp1_ERR = 1'b0;
                                      temp1_OFLOW = 1'b0;
                                      temp1_COUT = 1'b0;
                                      temp1_G = 1'b0;
                                      temp1_E = 1'b0;
                                      temp1_L = 1'b0;
                                  end
                    endcase
                end
            end
        end
        else begin
            temp1_ERR = 1;
        end
    end
endmodule
