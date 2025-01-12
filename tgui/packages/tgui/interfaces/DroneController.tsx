import { useBackend } from '../backend';
import { CameraConsole } from './CameraConsole';

export const DroneController = (props) => {
  const { act, data } = useBackend();
  // Extract `health` and `color` variables from the `data` object.
  const { health, maxhealth, serial_number } = data;
  return <CameraConsole />;
};
