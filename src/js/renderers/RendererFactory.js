import { MIPRenderer } from './MIPRenderer.js';
import { ISORenderer } from './ISORenderer.js';
import { EAMRenderer } from './EAMRenderer.js';
import { LAORenderer } from './LAORenderer.js';
import { MCSRenderer } from './MCSRenderer.js';
import { MCMRenderer } from './MCMRenderer.js';
import { WeightedDeltaRenderer } from './WeightedDeltaRenderer.js';
import { WeightedAnalogDecompositionRenderer } from './WeightedAnalogDecompositionRenderer.js';
import { DOSRenderer } from './DOSRenderer.js';
import { DepthRenderer } from './DepthRenderer.js';

export function RendererFactory(which) {
    switch (which) {
        case 'mip': return MIPRenderer;
        case 'iso': return ISORenderer;
        case 'eam': return EAMRenderer;
        case 'lao': return LAORenderer;
        case 'mcs': return MCSRenderer;
        case 'mcm': return MCMRenderer;
        case 'wdt': return WeightedDeltaRenderer;
        case 'wat': return WeightedAnalogDecompositionRenderer;
        case 'dos': return DOSRenderer;
        case 'depth': return DepthRenderer;

        default: throw new Error('No suitable class');
    }
}
