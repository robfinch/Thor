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

module Thor2024_fcu_issue(fcu_idle, could_issue, 
	head0, head1, head2, head3, head4, head5, head6, head7,
	iq, iqentry_fcu_issue);
input fcu_idle;
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
output que_bitmask_t iqentry_fcu_issue;

integer n;

// Don't issue to the fcu until the following instruction is enqueued.
// However, if the queue is full then issue anyway. A branch miss will likely occur.
// Issue flow controls in order unless SUPPORT_OOOFC is defined.
always_comb
begin
	iqentry_fcu_issue = 8'h00;
	if (fcu_idle) begin
    if (could_issue[head0] && iq[head0].fc) begin
      iqentry_fcu_issue[head0] = 1'b1;
    end
    else if (could_issue[head1] && iq[head1].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    )
    begin
      iqentry_fcu_issue[head1] = 1'b1;
    end
    else if (could_issue[head2] && iq[head2].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    ) begin
   		iqentry_fcu_issue[head2] = 1'b1;
    end
    else if (could_issue[head3] && iq[head3].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    	&& (!(iq[head2].fc && iq[head2].v) || SUPPORT_OOOFC)
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
    	)
    ) begin
   		iqentry_fcu_issue[head3] = 1'b1;
    end
    else if (could_issue[head4] && iq[head4].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    	&& (!(iq[head2].fc && iq[head2].v) || SUPPORT_OOOFC)
    	&& (!(iq[head3].fc && iq[head3].v) || SUPPORT_OOOFC)
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
   		iqentry_fcu_issue[head4] = 1'b1;
    end
    else if (could_issue[head5] && iq[head5].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    	&& (!(iq[head2].fc && iq[head2].v) || SUPPORT_OOOFC)
    	&& (!(iq[head3].fc && iq[head3].v) || SUPPORT_OOOFC)
    	&& (!(iq[head4].fc && iq[head4].v) || SUPPORT_OOOFC)
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
   		iqentry_fcu_issue[head5] = 1'b1;
    end
 
    else if (could_issue[head6] && iq[head6].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    	&& (!(iq[head2].fc && iq[head2].v) || SUPPORT_OOOFC)
    	&& (!(iq[head3].fc && iq[head3].v) || SUPPORT_OOOFC)
    	&& (!(iq[head4].fc && iq[head4].v) || SUPPORT_OOOFC)
    	&& (!(iq[head5].fc && iq[head5].v) || SUPPORT_OOOFC)
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
   		iqentry_fcu_issue[head6] = 1'b1;
    end
   
    else if (could_issue[head7] && iq[head7].fc
    	&& (!(iq[head0].fc && iq[head0].v) || SUPPORT_OOOFC)
    	&& (!(iq[head1].fc && iq[head1].v) || SUPPORT_OOOFC)
    	&& (!(iq[head2].fc && iq[head2].v) || SUPPORT_OOOFC)
    	&& (!(iq[head3].fc && iq[head3].v) || SUPPORT_OOOFC)
    	&& (!(iq[head4].fc && iq[head4].v) || SUPPORT_OOOFC)
    	&& (!(iq[head5].fc && iq[head5].v) || SUPPORT_OOOFC)
    	&& (!(iq[head6].fc && iq[head6].v) || SUPPORT_OOOFC)
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
   		iqentry_fcu_issue[head7] = 1'b1;
  	end
	end
end

endmodule