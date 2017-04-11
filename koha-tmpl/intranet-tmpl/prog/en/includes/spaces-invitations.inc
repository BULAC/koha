<h3>Currently invited to spaces</h3>
<table>
<tr>
<th>Type</th>
<th>Space</th>
<th>Start</th>
<th>End</th>
</tr>
[% FOREACH space IN spaces_invitations %]
<tr>
<td>[% space.type %]</td>
<td>[% space.name %]</td>
<td>[% space.start_date %]</td>
<td>[% space.end_date %]</td>
</tr>
[% END %]
</table>
