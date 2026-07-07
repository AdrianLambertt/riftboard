# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This wipes all boards and re-inserts the fixed demo board used on the
# public Fly.io instance (see Riftboard.Seeds / RESET_DEMO_DATA_ON_BOOT).

Riftboard.Seeds.reset()
