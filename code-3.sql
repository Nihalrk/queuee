create or replace function take_next_number(p_business uuid, p_day date)
returns int language plpgsql as declarenint;begininsertintoqueuecounters(businessid,day,lastnumber)values(pbusiness,pday,1)onconflict(businessid,day)doupdatesetlastnumber=queuecounters.lastnumber+1returninglastnumberinton;returnn;enddeclare n int;
begin
  insert into queue_counters (business_id, day, last_number)
  values (p_business, p_day, 1)
  on conflict (business_id, day)
    do update set last_number = queue_counters.last_number + 1
    returning last_number into n;
  return n;
enddeclarenint;begininsertintoqueuec​ounters(businessi​d,day,lastn​umber)values(pb​usiness,pd​ay,1)onconflict(businessi​d,day)doupdatesetlastn​umber=queuec​ounters.lastn​umber+1returninglastn​umberinton;returnn;end;
