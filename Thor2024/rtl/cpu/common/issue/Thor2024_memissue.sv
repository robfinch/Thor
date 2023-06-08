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

module Thor2024_memissue(rst, clk, 
	head0, head1, head2, head3, head4, head5, head6, head7,
	iqentry_memready, iqentry_stomp, iq, iqentry_memissue
);
input rst;
input clk;
input que_ndx_t head0;
input que_ndx_t head1;
input que_ndx_t head2;
input que_ndx_t head3;
input que_ndx_t head4;
input que_ndx_t head5;
input que_ndx_t head6;
input que_ndx_t head7;
input que_bitmask_t iqentry_memready;
input que_bitmask_t iqentry_stomp;
input iq_entry_t [QENTRIES-1:0] iq;
output que_bitmask_t iqentry_memissue;

always_ff @(posedge clk, posedge rst)
if (rst)
	iqentry_memissue <= 'd0;
else begin
	//
	// determine if the instructions ready to issue can, in fact, issue.
	// "ready" means that the instruction has valid operands but has not gone yet
	iqentry_memissue[ head0 ] <=	iqentry_memready[ head0 ];		// first in line ... go as soon as ready

	iqentry_memissue[ head1 ] <=	~iqentry_stomp[head1] && iqentry_memready[ head1 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head1].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head1].load || !iq[head0].fc);

	iqentry_memissue[ head2 ] <=	~iqentry_stomp[head2] && iqentry_memready[ head2 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head2].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head2].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head2].load ||
					    ( !iq[head0].fc && !iq[head1].fc));

	iqentry_memissue[ head3 ] <=	~iqentry_stomp[head3] && iqentry_memready[ head3 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head3].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head3].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head3].a1[$bits(address_t)-1:4] != iq[head2].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head3].load ||
					    ( !iq[head0].fc &&
					      !iq[head1].fc &&
					      !iq[head2].fc));

	iqentry_memissue[ head4 ] <=	~iqentry_stomp[head4] && iqentry_memready[ head4 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head4].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head4].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head4].a1[$bits(address_t)-1:4] != iq[head2].a1[$bits(address_t)-1:4]))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head4].a1[$bits(address_t)-1:4] != iq[head3].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head4].load ||
					    ( !iq[head0].fc &&
					    	!iq[head1].fc &&
					    	!iq[head2].fc &&
					    	!iq[head3].fc));

	iqentry_memissue[ head5 ] <=	~iqentry_stomp[head5] && iqentry_memready[ head5 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head5].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head5].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head5].a1[$bits(address_t)-1:4] != iq[head2].a1[$bits(address_t)-1:4]))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head5].a1[$bits(address_t)-1:4] != iq[head3].a1[$bits(address_t)-1:4]))
					&& (!iq[head4].mem || (iq[head4].agen & iq[head4].out) 
						|| (iq[head4].a1_v && iq[head5].a1[$bits(address_t)-1:4] != iq[head4].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head5].load ||
					    ( !iq[head0].fc &&
					    	!iq[head1].fc &&
					    	!iq[head2].fc &&
					    	!iq[head3].fc &&
					    	!iq[head4].fc));

	iqentry_memissue[ head6 ] <=	~iqentry_stomp[head6] && iqentry_memready[ head6 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head2].a1[$bits(address_t)-1:4]))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head3].a1[$bits(address_t)-1:4]))
					&& (!iq[head4].mem || (iq[head4].agen & iq[head4].out) 
						|| (iq[head4].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head4].a1[$bits(address_t)-1:4]))
					&& (!iq[head5].mem || (iq[head5].agen & iq[head5].out) 
						|| (iq[head5].a1_v && iq[head6].a1[$bits(address_t)-1:4] != iq[head5].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head5].load ||
					    ( !iq[head0].fc &&
					    	!iq[head1].fc &&
					    	!iq[head2].fc &&
					    	!iq[head3].fc &&
					    	!iq[head4].fc &&
					    	!iq[head5].fc
					    	));

	iqentry_memissue[ head7 ] <=	~iqentry_stomp[head7] && iqentry_memready[ head7 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					&& ~iqentry_memready[head6] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head0].a1[$bits(address_t)-1:4]))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head1].a1[$bits(address_t)-1:4]))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head2].a1[$bits(address_t)-1:4]))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head3].a1[$bits(address_t)-1:4]))
					&& (!iq[head4].mem || (iq[head4].agen & iq[head4].out) 
						|| (iq[head4].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head4].a1[$bits(address_t)-1:4]))
					&& (!iq[head5].mem || (iq[head5].agen & iq[head5].out) 
						|| (iq[head5].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head5].a1[$bits(address_t)-1:4]))
					&& (!iq[head6].mem || (iq[head6].agen & iq[head6].out) 
						|| (iq[head6].a1_v && iq[head7].a1[$bits(address_t)-1:4] != iq[head6].a1[$bits(address_t)-1:4]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head7].load ||
					    ( !iq[head0].fc &&
					    	!iq[head1].fc &&
					    	!iq[head2].fc &&
					    	!iq[head3].fc &&
					    	!iq[head4].fc &&
					    	!iq[head5].fc &&
					    	!iq[head6].fc
					    	));
end

endmodule
