const buildStatusPayload = () => ({
  status: 'ok',
  uptime: process.uptime(),
  timestamp: new Date().toISOString(),
});

const getHealth = (req, res) => {
  res.status(200).json(buildStatusPayload());
};

const getReady = (req, res) => {
  res.status(200).json(buildStatusPayload());
};

module.exports = {
  getHealth,
  getReady,
};
