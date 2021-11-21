# SavingHeal
WoW:Classic mod to announce clutch heals from the raid, and give credit where credit is due.
The mod will watch the last heal on each raid/party member, and if the next instance of damage would have caused that target to die, it is considered a 'saving heal' and will be announced.
Currently does not take into account damage absorbtion, such as priest shields.  I stopped playing so no plans to implement this.

# Notes
- This was last tested in the last phase of Classic pre-tbc.  Contributors welcome.
- Only ONE person should have this active per raid, otherwise you'll get multiple anounces.  That is why the default mode has been changed to 'off' and it must be specifically enabled using the slash commands below.

# Installation
Drop the SavingHeal folder into your AddOns folder.

# Commands
Usage: /sh or /savingheal
| Command      | Action                     |
| ------------ | -------------------------- |
| /sh off | Turn SH off |
| /sh raid | SH output in raid |
| /sh party | SH output in party |
| /sh say | SH output in say |
| /sh report | Output a small report on current stats |

# Future Development
Nothing planned currently.  If you want to contribute or make fixes, by all means send a request to get added to the project.
If you want to use this code/concept in your own mod, a shout out would be appreciated. :]