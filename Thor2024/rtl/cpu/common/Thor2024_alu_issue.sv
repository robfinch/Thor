// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ============================================================================

import Thor2024pkg::*;

module Thor2024_alu_issue(alu0_idle, alu1_idle, iqentry_islot, could_issue, 
	head0, head1, head2, head3, head4, head5, head6, head7,
	iq, iqentry_issue);
input alu0_idle;
input alu1_idle;
output reg [1:0] iqentry_islot [0:QENTRIES-1];
input que_bitmask_t could_issue;
input que_ndx_t head0;
input que_ndx_t head1;
input que_ndx_t head2;
input que_ndx_t head3;
input que_ndx_t head4;
input que_ndx_t head5;
input que_ndx_t head6;
input que_ndx_t head7;
input iq_entry_t [QENTRIES-1:0] iq;
output que_bitmask_t iqentry_issue;

integer n;

// FPGAs do not handle race loops very well.
// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
// ToDo: fix the memory synchronization, see fp_issue below

always_comb
begin
	iqentry_issue = 'd0;
	for (n = 0; n < QENTRIES; n = n + 1)
		iqentry_islot[n] = 2'b00;
	
	// aluissue is a task
	if (alu0_idle) begin
		if (could_issue[head0] && iq[head0].alu
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = 1'b1;
		  iqentry_islot[head0] = 2'b00;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iq[head1].alu
		)
		begin
		  iqentry_issue[head1] = 1'b1;
		  iqentry_islot[head1] = 2'b00;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iq[head2].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		)
		begin
			iqentry_issue[head2] = 1'b1;
			iqentry_islot[head2] = 2'b00;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iq[head3].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
			)
		) begin
			iqentry_issue[head3] = 1'b1;
			iqentry_islot[head3] = 2'b00;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iq[head4].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		) begin
			iqentry_issue[head4] = 1'b1;
			iqentry_islot[head4] = 2'b00;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iq[head5].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		) begin
			iqentry_issue[head5] = 1'b1;
			iqentry_islot[head5] = 2'b00;
		end
		else if (could_issue[head6] && !iqentry_issue[head6] && iq[head6].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		) begin
			iqentry_issue[head6] = 1'b1;
			iqentry_islot[head6] = 2'b00;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iq[head7].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		&& (!(iq[head6].v && iq[head6].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v)
		 	&&   (!iq[head5].v))
			)
		) begin
			iqentry_issue[head7] = 1'b1;
			iqentry_islot[head7] = 2'b00;
		end
	end

	if (NALU > 1 && alu1_idle) begin
		if (could_issue[head0] && iq[head0].alu
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = 1'b1;
		  iqentry_islot[head0] = 2'b01;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iq[head1].alu)
		begin
		  iqentry_issue[head1] = 1'b1;
		  iqentry_islot[head1] = 2'b01;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iq[head2].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		)
		begin
			iqentry_issue[head2] = 1'b1;
			iqentry_islot[head2] = 2'b01;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iq[head3].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
			)
		) begin
			iqentry_issue[head3] = 1'b1;
			iqentry_islot[head3] = 2'b01;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iq[head4].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		) begin
			iqentry_issue[head4] = 1'b1;
			iqentry_islot[head4] = 2'b01;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iq[head5].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		) begin
			iqentry_issue[head5] = 1'b1;
			iqentry_islot[head5] = 2'b01;
		end
		else if (could_issue[head6] && !iqentry_issue[head6] && iq[head6].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		) begin
			iqentry_issue[head6] = 1'b1;
			iqentry_islot[head6] = 2'b01;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iq[head7].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		&& (!(iq[head6].v && iq[head6].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v)
		 	&&   (!iq[head5].v))
			)
		) begin
			iqentry_issue[head7] = 1'b1;
			iqentry_islot[head7] = 2'b01;
		end
	end
end

endmodule