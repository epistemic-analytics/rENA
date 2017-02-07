debug <- F;

print("Global file loaded.")

housesList = list(
  list(house="Stark", color="#4c4c4c", img = T),
  list(house="Lannister", color="#a41d1e", img = T),
  list(house="Baratheon", color="#c4c452", img = T),
  list(house="Targaryen", color="#2c2f30", img = T),
  list(house="Martell", color="#f0863a", img = T),
  list(house="Tyrell", color="#7ace94", img = T),
  list(house="Tully", color="#2c2f66", img = T),
  list(house="Arryn", color="#1671F4", img = T),
  list(house="Greyjoy", color="#2c2f66", img = T),
  list(house="Frey", color="#133547", img = T),
  list(house="Bolton", color="#1e1e1e", img = T),
  list(house="Wildlings", color="#232323", img = T),
  list(house="Extra", color="#a6d3eb", img = F)
)

housesListJSON = rjson::toJSON(housesList)


