//======================================================================
//
// keywrap_core.v
// --------------
// RFC3394 keywrap core.
// The core works on blocks of 64 bits. The supported key lengths
// are 128 and 256 bits.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2015 Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module keywrap_core(
                    input wire            clk,
                    input wire            reset_n,

                    input wire            encdec,
                    input wire            init,
                    input wire            next,
                    output wire           ready,

                    input wire [255 : 0]  key,
                    input wire            keylen,

                    input wire [63  : 0]  block,
                    output wire [63  : 0] result,
                    input wire            result_valid
                   );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam DEBUG            = 0;

  localparam CTRL_IDLE = 3'h0;
  localparam CTRL_INIT = 3'h1;
  localparam CTRL_DONE = 3'h7;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [63 : 0]   a_reg;
  reg [63 : 0]   a_new;
  reg            a_we;
  reg            a_init;
  reg            a_next;

  reg [3 : 0]    keywrap_ctrl_reg;
  reg [3 : 0]    keywrap_ctrl_new;
  reg            keywrap_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------



  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign error     = tmp_error;

  assign core_key = {key0_reg, key1_reg, key2_reg, key3_reg,
                     key4_reg, key5_reg, key6_reg, key7_reg};

  assign core_block  = {block0_reg, block1_reg, block2_reg, block3_reg};
  assign core_init   = init_reg;
  assign core_next   = next_reg;
  assign core_encdec = encdec_reg;
  assign core_keylen = keylen_reg;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  aes_core aes_core_inst(
                         .clk(clk),
                         .reset_n(reset_n),

                         .encdec(core_encdec),
                         .init(core_init),
                         .next(core_next),
                         .ready(core_ready),

                         .key(core_key),
                         .keylen(core_keylen),

                         .block(core_block),
                         .result(core_result),
                         .result_valid(core_valid)
                        );


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin

        end
      else
        begin

        end
    end // reg_update


  //----------------------------------------------------------------
  // Datapath. Or a register logic, if we do this separately.
  //----------------------------------------------------------------
  always @*
    begin
      a_new = 64'h0000000000000000;
      a_we  = 1'b0;

      if (a_init)
        begin
          a_new = 64'ha6a6a6a6a6a6a6a6;
          a_we  = 1'b1;
        end
    end


  //----------------------------------------------------------------
  // keywrap_ctrl
  //
  // Control FSM for the keyrap core.
  //----------------------------------------------------------------
  always @*
    begin : keywrap_ctrl

    end

endmodule // keywrap_core

//======================================================================
// EOF keywrap_core.v
//======================================================================
