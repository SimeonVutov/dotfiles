set confirm off

# Enable pretty printing (Crucial for structures)
set print pretty on
set print array on
set print array-indexes on

define phead
  set $ptr = $arg1
  plistdata $arg0
end
document phead
Print the first element of a list. 
Usage: phead [type] [list_pointer]
Example: phead char my_list
end

define pnext
  set $ptr = $ptr->next
  plistdata $arg0
end
document pnext
Step to the next element and print it.
Usage: pnext [type]
Example: pnext char
end

define plistdata
  if $ptr
    set $pdata = $ptr->data
  else
    set $pdata = 0
  end
  
  if $pdata
    p ($arg0*)$pdata
  else
    printf "NULL\n"
  end
end
document plistdata
Helper macro used by phead and pnext.
end

# Visual delimiters for print commands
define hook-print
  echo <----\n
end
define hookpost-print
  echo ----->\n
end
